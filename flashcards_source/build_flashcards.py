#!/usr/bin/env python3

r"""
build_flashcards.py
====================

Reads the ALREADY-COMPILED flashcards_source/tex/all_flashcards.pdf and
turns it, together with all_flashcards.tex and preamble.tex, into the
.webp pairs + manifest consumed by the Flutter app.

This script does NOT run LaTeX. The maintainer compiles
all_flashcards.tex themselves (however they normally do - editor,
latexmk, whatever) and checks the PDF looks right before running this.
The script just confirms that happened, then treats the PDF as read-only
ground truth and walks it in lockstep with the source cards: page
2i+1 = card i's front, page 2i+2 = card i's back.

IMPORTANT - the one real risk of this design: it assumes every
\begin{frage}...\end{frage} and \begin{antwort}...\end{antwort} produces
EXACTLY one physical page. If any single card overflows to a second
page, every card after it silently shifts by one page - fronts pair with
the wrong backs, with no error from LaTeX itself. The page-count sanity
check below catches the aggregate case (short/over on total pages) and
aborts loudly, but can't by itself tell you WHICH card overflowed. If it
fires, check all_flashcards.pdf directly around where the count goes
wrong (or bisect with a smaller source file) before re-running.

Card ids are a hash of (category, frage) ONLY - not the antwort, and
not the preamble. Answer text is fixed but gets re-laid-out often
(spacing, line breaks, minor rewording), and none of that should count
as "a different card" for the app's proficiency tracking - only the
question identifies a card. The separate content hash used for cache
invalidation DOES include the antwort and the preamble text, so an
answer edit or a style change still correctly triggers re-extraction of
that card's images.

Requirements (all external, not pip-installable):
    - poppler-utils (`pdfinfo`, `pdftoppm`) for page counting and
      PDF -> PNG rasterization
    - libwebp (`cwebp`) for PNG -> WEBP conversion

Usage:

    cd flashcards_source && python3 build_flashcards.py
    cd flashcards_source && python3 build_flashcards.py --force

Fixed layout, relative to this file's own location (no flags - the
project is always laid out this way):

    <project root>/
      flashcards_source/
        build_flashcards.py     <- this file
        tex/
          all_flashcards.tex
          all_flashcards.pdf    <- already compiled by the maintainer
          preamble.tex
          schema_*.pdf/png
      assets/
        flashcards/<category>/<card_id>_front.webp / _back.webp
        flashcards_manifest.json
        .build_cache.json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

# Must match lib/constants/categories.dart in the Flutter app exactly.
VALID_CATEGORIES = {"Analysis", "Geometrie", "Stochastik"}

# A card can be excluded from the deck (e.g. the cover/title card) by
# tagging it "% category: skip".
SKIP_CATEGORY = "skip"

DPI = 400

# This script lives directly in flashcards_source/.
SCRIPT_DIR = Path(__file__).resolve().parent
TEX_DIR = SCRIPT_DIR / "tex"
SOURCE = TEX_DIR / "all_flashcards.tex"
PREAMBLE_PATH = TEX_DIR / "preamble.tex"
DECK_PDF = TEX_DIR / "all_flashcards.pdf"
OUT_ASSETS = SCRIPT_DIR.parent / "assets"

CARD_RE = re.compile(
    r"\\begin\{frage\}(?P<frage>.*?)\\end\{frage\}"
    r"\s*"
    r"\\begin\{antwort\}(?P<antwort>.*?)\\end\{antwort\}",
    re.DOTALL,
)
CATEGORY_COMMENT_RE = re.compile(r"^\s*%\s*category:\s*(\S+)\s*$")


def _run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    """subprocess.run wrapper that prints the failing command's stderr
    before re-raising - CalledProcessError carries .stdout/.stderr, but
    silently, so an uncaught one only shows a generic traceback with no
    indication of what pdftoppm/cwebp/pdfinfo actually complained about."""
    try:
        return subprocess.run(cmd, check=True, capture_output=True, text=True, **kwargs)
    except subprocess.CalledProcessError as e:
        print(f"error: command failed: {' '.join(cmd)}", file=sys.stderr)
        if e.stdout:
            print("--- stdout ---", file=sys.stderr)
            print(e.stdout, file=sys.stderr)
        if e.stderr:
            print("--- stderr ---", file=sys.stderr)
            print(e.stderr, file=sys.stderr)
        raise


def _hash(*parts: str) -> str:
    h = hashlib.sha256()
    for p in parts:
        h.update(p.encode("utf-8"))
    return h.hexdigest()[:16]


@dataclass
class CardSource:
    index: int  # position in the source file, for stable ordering
    category: str
    frage_tex: str
    antwort_tex: str

    @property
    def card_id(self) -> str:
        # Hash of (category, frage) ONLY. Neither the antwort nor the
        # preamble factor in: answer layout gets tweaked often and
        # shouldn't reset proficiency tracking for a card the user
        # already knows. Only the question text identifies a card.
        return f"{self.category.lower()}_{_hash(self.category, self.frage_tex)}"

    def content_hash(self, preamble_text: str) -> str:
        # Used for cache invalidation only. Includes the antwort and the
        # preamble so an answer edit or a rendering/style change
        # re-extracts this card's images, without touching card_id.
        return _hash(self.category, self.frage_tex, self.antwort_tex, preamble_text)


def parse_cards(tex_path: Path) -> list[CardSource]:
    """Scans all_flashcards.tex for tagged frage/antwort pairs."""
    text = tex_path.read_text(encoding="utf-8")

    # Walk the file top to bottom, tracking the most recent
    # "% category: X" comment as sticky state, and pairing that state
    # with each frage/antwort block encountered after it.
    lines = text.splitlines(keepends=True)
    current_category: str | None = None
    line_categories: list[str | None] = []
    for line in lines:
        m = CATEGORY_COMMENT_RE.match(line)
        if m:
            current_category = m.group(1)
        line_categories.append(current_category)

    cards: list[CardSource] = []
    for i, match in enumerate(CARD_RE.finditer(text)):
        start_line = text.count("\n", 0, match.start())
        category = (
            line_categories[start_line] if start_line < len(line_categories) else None
        )

        if category is None:
            raise ValueError(
                f"Card #{i} (starting near line {start_line + 1}) has no "
                f"'% category: X' marker above it in the source."
            )
        if category == SKIP_CATEGORY:
            continue
        if category not in VALID_CATEGORIES:
            raise ValueError(
                f"Card #{i} (line {start_line + 1}) is tagged "
                f"'{category}', which isn't one of {sorted(VALID_CATEGORIES)}. "
                f"Check lib/constants/categories.dart stays in sync."
            )

        cards.append(
            CardSource(
                index=i,
                category=category,
                frage_tex=match.group("frage").strip(),
                antwort_tex=match.group("antwort").strip(),
            )
        )

    return cards


def pdf_page_count(pdf_path: Path) -> int:
    result = _run(["pdfinfo", str(pdf_path)])
    for line in result.stdout.splitlines():
        if line.startswith("Pages:"):
            return int(line.split(":", 1)[1].strip())
    raise RuntimeError(f"Couldn't parse page count from pdfinfo output for {pdf_path}")


def extract_page_to_webp(pdf_path: Path, page: int, out_path: Path) -> None:
    """Rasterizes one page straight to webp - no cropping. The page is
    already the exact target aspect ratio (preamble.tex fixes it), so
    cropping would only throw that away."""
    out_path.parent.mkdir(parents=True, exist_ok=True)

    tmp_prefix = out_path.with_suffix("")
    _run(
        [
            "pdftoppm",
            "-png",
            "-r",
            str(DPI),
            "-f",
            str(page),
            "-l",
            str(page),
            "-singlefile",
            str(pdf_path),
            str(tmp_prefix),
        ]
    )
    png_path = tmp_prefix.with_suffix(".png")
    if not png_path.exists():
        raise RuntimeError(f"pdftoppm produced no output for page {page} of {pdf_path}")

    _run(["cwebp", "-lossless", "-z", "9", str(png_path), "-o", str(out_path)])
    png_path.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build flashcards webp assets and manifest from compiled TeX PDF."
    )
    parser.add_argument(
        "-f",
        "--force",
        action="store_true",
        help="Force re-extraction of all flashcards by ignoring and resetting cache and manifest.",
    )
    args = parser.parse_args()

    answer = input("Did you compile all_flashcards.tex? (y/n) ").strip().lower()
    if answer != "y":
        print("Compile all_flashcards.tex first, then re-run this script.")
        return 1

    for tool in ("pdfinfo", "pdftoppm", "cwebp"):
        if shutil.which(tool) is None:
            print(f"error: required tool '{tool}' not found on PATH", file=sys.stderr)
            return 1

    if not DECK_PDF.exists():
        print(f"error: {DECK_PDF} not found", file=sys.stderr)
        return 1
    if not PREAMBLE_PATH.exists():
        print(f"error: {PREAMBLE_PATH} not found", file=sys.stderr)
        return 1
    preamble_text = PREAMBLE_PATH.read_text(encoding="utf-8")

    cards = parse_cards(SOURCE)
    print(f"Parsed {len(cards)} cards.")
    if not cards:
        print("error: no cards to render", file=sys.stderr)
        return 1

    expected_pages = 2 * len(cards)
    actual_pages = pdf_page_count(DECK_PDF)
    if actual_pages != expected_pages:
        print(
            f"error: expected {expected_pages} pages (2 per card x {len(cards)} "
            f"cards) but {DECK_PDF} has {actual_pages}. At least one card "
            f"almost certainly overflowed to a second page, which would "
            f"silently mis-pair every following card's front/back - aborting "
            f"instead. Check {DECK_PDF} directly (or bisect with a smaller "
            f"source file) to find the overflowing card before re-running.",
            file=sys.stderr,
        )
        return 1
    print(f"Page count check OK: {actual_pages} pages for {len(cards)} cards.")

    cache_path = OUT_ASSETS / ".build_cache.json"
    manifest_path = OUT_ASSETS / "flashcards_manifest.json"

    if args.force:
        print("Force mode enabled: resetting cache and manifest files...")
        if cache_path.exists():
            cache_path.unlink()
        if manifest_path.exists():
            manifest_path.unlink()
        cache = {}
    else:
        cache = (
            json.loads(cache_path.read_text(encoding="utf-8"))
            if cache_path.exists()
            else {}
        )

    def save_cache() -> None:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(
            json.dumps(cache, indent=2, ensure_ascii=False), encoding="utf-8"
        )

    manifest: list[dict] = []

    def save_manifest() -> None:
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8"
        )

    extracted_count = 0

    for i, card in enumerate(cards):
        front_page = 2 * i + 1
        back_page = 2 * i + 2

        front_path = (
            OUT_ASSETS
            / "flashcards"
            / card.category.lower()
            / f"{card.card_id}_front.webp"
        )
        back_path = (
            OUT_ASSETS
            / "flashcards"
            / card.category.lower()
            / f"{card.card_id}_back.webp"
        )

        manifest.append(
            {
                "id": card.card_id,
                "category": card.category,
                "front": f"assets/flashcards/{card.category.lower()}/{card.card_id}_front.webp",
                "back": f"assets/flashcards/{card.category.lower()}/{card.card_id}_back.webp",
            }
        )
        # Write manifest to disk immediately on every step
        save_manifest()

        content_hash = card.content_hash(preamble_text)
        up_to_date = (
            cache.get(card.card_id) == content_hash
            and front_path.exists()
            and back_path.exists()
        )
        if up_to_date:
            continue

        print(
            f"  extracting {card.card_id} ({card.category}) pages {front_page}-{back_page} ..."
        )
        extract_page_to_webp(DECK_PDF, front_page, front_path)
        extract_page_to_webp(DECK_PDF, back_page, back_path)

        cache[card.card_id] = content_hash
        save_cache()
        extracted_count += 1

    live_ids = {c.card_id for c in cards}
    cache = {k: v for k, v in cache.items() if k in live_ids}
    save_cache()

    print(
        f"Extracted {extracted_count} card(s), {len(cards) - extracted_count} unchanged."
    )
    print(f"Manifest written to {manifest_path} ({len(manifest)} cards).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
