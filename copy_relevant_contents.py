import os
import subprocess
from pathlib import Path

# Files and directories to include
TARGET_PATHS = [
    Path("pubspec.yaml"),
    Path("analysis_options.yaml"),
    Path("lib"),
    Path("flashcards_source"),
]

# File extensions allowed
# ALLOWED_EXTENSIONS = {".dart", ".yaml", ".json"}

# Generated files to skip (prevents wasting token limit)
IGNORE_SUFFIXES = {".g.dart", ".freezed.dart"}


def should_process_file(file_path: Path) -> bool:
    if not file_path.is_file():
        return False
    # if file_path.suffix not in ALLOWED_EXTENSIONS:
    #     return False
    if any(file_path.name.endswith(suffix) for suffix in IGNORE_SUFFIXES):
        return False
    return True


def gather_contents() -> str:
    root = Path.cwd()
    output_blocks = []

    for target in TARGET_PATHS:
        full_target = root / target
        if not full_target.exists():
            continue

        files = (
            [full_target] if full_target.is_file() else sorted(full_target.rglob("*"))
        )

        for file_path in files:
            if should_process_file(file_path):
                relative_path = file_path.relative_to(root)
                try:
                    content = file_path.read_text(encoding="utf-8")
                    output_blocks.append(
                        f"// contents of file {relative_path}:\n{content.strip()}\n"
                    )
                except Exception as e:
                    print(f"Skipping {relative_path}: {e}")

    return "\n\n".join(output_blocks)


def copy_to_clipboard(text: str) -> None:
    process = subprocess.Popen(["pbcopy"], stdin=subprocess.PIPE, close_fds=True)
    process.communicate(input=text.encode("utf-8"))


def write_to_file(text):
    with open(os.path.expanduser("~/Downloads/all_relevant_contents.txt"), "w") as f:
        f.write(text)


if __name__ == "__main__":
    combined_content = gather_contents()
    if combined_content.strip():
        write_to_file(combined_content)
        copy_to_clipboard(combined_content)
        print("✓ Flutter project context copied to clipboard!")
    else:
        print("⚠ No matching files found.")
