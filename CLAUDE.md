# CLAUDE.md

Guidance for Claude Code when working in this repo.

## Project

`akademus_app` — a Flutter app for Akademus GmbH. German-language math learning
app for pupils: flashcard study (Analysis, Geometrie, Stochastik) and a quiz
mode (Markdown + LaTeX questions, live-rendered), with a stats section
currently a placeholder on the home screen. Deployed to Firebase Hosting at
https://akademus-app-preview.web.app — see "Deployment" below. Current work
is on branch `feature/quiz`, open as PR #9 against `main`.

- All user-facing strings are German. Keep new UI text German unless told
  otherwise.
- Brand colors, used throughout instead of a Theme: `myBlue = 0xFF264358`,
  `myOrange = 0xFFF5AC26`. Reused per-widget as local `Color` fields rather
  than a shared `ThemeData` — match that pattern rather than introducing
  `Theme.of(context)` lookups.

## Architecture
lib/
main.dart - flashcard/quiz app entry point (HomeScreen)
admin_main.dart - second, separate entry point: the quiz question-bank
  admin page (see "Quiz admin page" below). Not reachable from main.dart.
constants/categories.dart - canonical category list (label + icon), shared
  by flashcards and quiz
models/ - immutable data classes (@immutable, meta package)
services/ - business logic, read manifest + storage
storage/ - SharedPreferences-backed persistence
admin/ - question-bank editor screen/form/repository (admin_main.dart only)
presentation/
screens/ - one file per screen
widgets/app_chrome.dart - shared background + footer wrappers
widgets/rich_content.dart - Markdown + inline/block LaTeX renderer, used by
  quiz prompts/options/explanations and the admin editor's live preview



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
- Quiz content is the opposite of flashcards: `QuizQuestion.prompt`/
  `explanation`/`QuizOption.text` are live-authored Markdown strings with
  inline `$..$` / block `$$..$$` LaTeX, rendered at runtime by
  `RichContent` (`flutter_markdown_plus` + `flutter_math_fork`), not
  pre-compiled images. Loaded from `assets/quiz_manifest.json` by
  `QuizService`, filtered/shuffled/capped the same way `FlashcardService`
  does for flashcards. Deliberately **not** sharing a model with
  `Flashcard` — see `lib/models/quiz_question.dart`'s doc comment.
- `assets/datenschutz.html` is the **single** source for the
  Datenschutzerklärung — rendered in-app by `PrivacyInfoScreen` (via
  `flutter_html`) and served as the public `/datenschutz` page (Firebase
  rewrite, see "Deployment"). Don't recreate a separate `.txt` or `web/`
  copy; past drift between two copies is why this got consolidated.

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

## Quiz feature

`QuizScreen` is a sibling of `FlashcardScreen`, not a variant of it —
flashcards are self-graded (swipe/tap "knew it"), quiz questions are
actually graded (`QuizQuestion.isCorrect`). Both still produce a
`SessionScore` through the same `SessionHistoryStorage`, confirming the
original guess that a parallel scoring system wasn't needed.

- `QuestionType`: `singleChoice`, `multipleChoice`, `shortAnswer` (case-
  insensitive match against `acceptedAnswers`). Grading lives on
  `QuizQuestion.isCorrect`, not in the screen.
- `QuizScreen.category(label)` (topic tile, ungraded) and
  `QuizScreen(config: ...)` mirror `FlashcardScreen`'s two entry points —
  same `StudySessionConfig` branch-point convention.
- `StatsScreen` takes an `onRetry: WidgetBuilder` (not a hardcoded
  `FlashcardScreen`) specifically so both flashcards and quiz can reuse it
  without either screen knowing about the other.

## Quiz admin page

`lib/admin_main.dart` is a **second, independent app entry point** — a
question-bank editor, reusing `QuizQuestion`/`RichContent` from the main
app but with its own `main()`/`MaterialApp`. It is never imported by
`main.dart`; the only link between them is the notice box on the home
screen (`QuizEditorNoticeBox` in `main.dart`) that opens the deployed
`/edit-quiz` URL via `url_launcher`.

- Persistence goes through `QuestionRepository` (`lib/admin/`), an
  interface with one implementation, `JsonQuestionRepository`: `loadAll()`
  prompts a browser file picker, `saveAll()` triggers a JSON download.
  Swapping to Firestore later means writing a new implementation and
  changing one constructor call in `AdminHomeScreen` — the editor UI
  doesn't know how storage works.
- `JsonQuestionRepository` uses `package:web` + `dart:js_interop`, **not**
  `dart:html` — this app is built with `--wasm` (see Deployment) and
  `dart:html` doesn't compile under dart2wasm. If you touch this file,
  keep it that way.
- Run it directly: `flutter run -d chrome --target=lib/admin_main.dart`.

## Deployment

Firebase Hosting, project `akademus-app-preview`, config in
`firebase.json`. Two Flutter apps are deployed to *one* site as separate
subpaths, not two Hosting sites — `deploy.sh` builds both (in this order;
the main app owns `build/web` and must build first) and runs
`firebase deploy`:
```
flutter build web --wasm
flutter build web --wasm --target=lib/admin_main.dart --base-href /edit-quiz/ --output=build/web/edit-quiz
firebase deploy
```
- Routing: `firebase.json` rewrites `/edit-quiz/**` and `/datenschutz/**`
  to their respective `index.html`/asset before the SPA catch-all. Note
  Flutter's web asset bundling nests declared assets one level deeper than
  you'd expect (`assets/datenschutz.html` → physical path
  `build/web/assets/assets/datenschutz.html`) — the `/datenschutz` rewrite
  destination accounts for this; check actual `build/web/assets/` layout
  before "fixing" what looks like a wrong path.
- Caching: `firebase.json` sets `Cache-Control: no-cache` on everything.
  Flutter web doesn't content-hash `index.html`/`main.dart.js`/`.wasm`
  filenames, so Firebase's default `max-age=3600` let browsers serve a
  stale app shell for up to an hour after a deploy. Don't add per-path
  long-lived caching without checking a file is actually content-hashed
  first — `assets/quiz_manifest.json` and `assets/datenschutz.html` are
  **not** hashed and must stay revalidate-on-load, or edits made in the
  admin page would never reach existing visitors.
- Known gotcha: `.dart_tool/flutter_build/`'s cached
  `web_plugin_registrant.dart` can go stale after adding a new plugin
  dependency (observed with `url_launcher`: `.flutter-plugins-dependencies`
  correctly listed it, but the cached registrant still only registered
  `shared_preferences` and calls threw `MissingPluginException` in the
  deployed build). If a newly-added plugin silently no-ops on web, run
  `flutter clean` before rebuilding, don't assume the plugin/code is
  broken.

## Known placeholders / not yet implemented

- Home screen's "Lern-Statistiken" button routes to `PlaceholderScreen` —
  not built yet. `SessionHistoryStorage` already exists and is the natural
  data source once it's built.
- `/edit-quiz` has no access control — anyone with the URL can edit
  questions. Deliberately deferred, not an oversight.
- No tests yet.

## Commands
flutter analyze   # run before considering any change done
flutter test
flutter run
./deploy.sh        # builds both web targets (--wasm) and firebase deploys