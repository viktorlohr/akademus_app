# CLAUDE.md

Guidance for Claude Code when working in this repo.

## Project

`akademus_app` — a Flutter app for Akademus GmbH. German-language math learning
app for pupils: flashcard study (Analysis, Geometrie, Stochastik), with a
quiz feature planned and a stats section currently a placeholder on the
home screen.

- All user-facing strings are German. Keep new UI text German unless told
  otherwise.
- Brand colors, used throughout instead of a Theme: `myBlue = 0xFF264358`,
  `myOrange = 0xFFF5AC26`. Reused per-widget as local `Color` fields rather
  than a shared `ThemeData` — match that pattern rather than introducing
  `Theme.of(context)` lookups.

## Architecture
lib/
constants/categories.dart - canonical category list (label + icon)
models/ - immutable data classes (@immutable, meta package)
services/ - business logic, read manifest + storage
storage/ - SharedPreferences-backed persistence
presentation/
screens/ - one file per screen
widgets/app_chrome.dart - shared background + footer wrappers



**Flow of a study session:**
`StudySessionConfig` (what to study) → `FlashcardService.getCardsForSession`
(builds the `List<StudyCard>`) → `FlashcardScreen` (study UI, calls
`rateCard` per card) → on the last card, builds a `SessionScore` → if
`config.rated`, saved via `SessionHistoryStorage` → `StatsScreen`.

There are two entry points into `FlashcardScreen`:
- `FlashcardScreen.category(label)` — tapping a topic tile. Single category,
  no card limit, weakest-proficiency-first, **not** rated (nothing written
  to session history).
- `FlashcardScreen(config: ...)` — the "rated session" flow from
  `SessionSetupScreen`. Multiple categories allowed, capped card count,
  weighted-random order, `rated: true`.

Both paths share all screen code — `StudySessionConfig` is the only branch
point. When adding a new way to start a session, extend `StudySessionConfig`
rather than adding a second constructor path through `FlashcardScreen`.

## Data model / content pipeline

- Flashcard content (front/back images) is **not authored in the app**. It's
  pre-rendered LaTeX compiled to `.webp` elsewhere (see
  `flashcards_source/praeambel_app_standalone.tex`, not part of this Flutter
  project) and bundled as assets, indexed by
  `assets/flashcards_manifest.json`. `Flashcard` is a dumb data holder — id,
  category, two image paths. There is no text/markdown content to parse.
- `kCardAspectRatio` in `flashcard_screen.dart` (105/148, ISO A6) **must**
  match the LaTeX source's paper size. If someone changes the LaTeX
  paperwidth/paperheight, this constant needs a matching update or images
  will letterbox.
- `flashcardCategories` in `constants/categories.dart` is the single source
  of truth for category label + icon. The `category` string on each
  `Flashcard` must exactly match a label here. Adding a category means:
  new entry in `categories.dart`, matching assets folder, matching entries
  in the manifest, matching folder registered under `flutter.assets` in
  `pubspec.yaml`.

## Persistence

Two independent `SharedPreferences`-backed stores, both under
`lib/storage/`:
- `ProficiencyStorage` — per-card proficiency (0–4), used to order weakest
  cards first in non-rated sessions and to weight the shuffle in rated ones.
  Adjusted ±1 by `FlashcardService.rateCard` on every swipe/tap, regardless
  of session type.
- `SessionHistoryStorage` — list of `SessionScore` (grade, points, accuracy),
  capped at 50 entries, newest first. Only written for `rated` sessions.
  Keyed for "personal best" lookups by the *set* of categories in the
  session (order-independent — see `bestFor`).

These are deliberately separate: proficiency is long-term per-card memory
strength; session history is short-term graded performance. Don't conflate
them or read one to compute the other.

## Scoring

`SessionScore.points` and `.grade` (German A–E band) are computed, not
stored — only the raw `total`/`known`/`maxStreak` are persisted, so changing
the scoring formula in `session_score.dart` retroactively re-grades all
history on next read. This is intentional; don't add a stored `points`
field without good reason.

## Conventions

- Screens follow a consistent chrome: `AppBar` with the Akademus logo image
  (not text) at `toolbarHeight: 100`, white background,
  `scrolledUnderElevation: 0`. Body wrapped in `AppBackground` or
  `GlobalFooterWrapper` from `presentation/widgets/app_chrome.dart` — the
  footer tap-target for Impressum/Datenschutz is part of nearly every
  screen and shouldn't be dropped.
- `GridSelectionScreen` is a generic 2-column tile grid used by topic
  selection (and can take an optional `action` widget below the grid for
  screen-level CTAs, e.g. "Session starten").
- New persisted models get a `toJson`/`fromJson` pair and a `@immutable`
  annotation via `package:meta`, following `Flashcard` and `SessionScore`.
- Service classes cache expensive reads (`FlashcardService._cache` for the
  manifest) as `static` so re-constructing the service (e.g. a new one per
  screen) doesn't re-read from disk.
- Service/storage instances belong on the `State`, not the `StatefulWidget`
  — widgets should stay cheap/immutable to rebuild.

## Deprecated / removed

- **AI Tutor ("KI Mathe-Tutor") is cancelled.** It's been removed from the
  home screen menu. Do not re-add a tutor/chat entry point, and treat any
  leftover references to it (comments, unused imports, string literals) as
  cleanup, not as a feature to restore.

## Planned: quiz feature

A quiz mode is planned but not yet started. No code exists for it yet —
treat this as a heads-up for design, not a description of current state.
Expected shape, based on how the flashcard/session code is structured:

- Likely a sibling of "rated session" rather than a variant of
  `FlashcardScreen`: flashcards are self-graded (user says whether *they*
  knew it), a quiz implies actual right/wrong answers (multiple choice or
  input), which `FlashcardScreen`'s swipe/flip interaction doesn't support.
  Expect a new screen rather than a config flag on `StudySessionConfig`.
- Will likely still want to feed off `flashcards_manifest.json` and
  `flashcardCategories` for content/category consistency — check with
  whoever specs it whether quiz questions come from the same manifest
  (e.g. front image as question) or need a new content type before
  inventing a parallel pipeline.
- `SessionScore` / `SessionHistoryStorage` were written generically enough
  (title + categories + total/known/streak) that a quiz run producing a
  `SessionScore` and going through the existing history store is plausible
  — don't assume a parallel scoring/history system is needed without
  checking whether the existing one fits first.

## Known placeholders / not yet implemented

- Home screen's "Lern-Statistiken" button routes to `PlaceholderScreen` —
  not built yet. `SessionHistoryStorage` already exists and is the natural
  data source once it's built.
- Quiz feature (see above).
- No tests yet.

## Commands
flutter analyze # run before considering any change done
flutter test
flutter run