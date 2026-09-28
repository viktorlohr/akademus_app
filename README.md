# akademus_app

German-language Flutter math learning app for pupils, built for Akademus
GmbH. Two study modes share one scoring/history system:

- **Karteikarten (flashcards)** — pre-rendered LaTeX images (Analysis,
  Geometrie, Stochastik), self-graded by swipe.
- **Quiz** — live-rendered Markdown + LaTeX questions, auto-graded
  (single/multiple choice, short answer).
- **Lern-Statistiken** — streaks, trend chart, and per-category accuracy
  aggregated from rated sessions of both modes.

A separate admin page (`lib/admin_main.dart`, deployed at `/edit-quiz`)
lets question-bank content be edited without touching the main app.

Deployed to Firebase Hosting: https://akademus-3135e.web.app

See [CLAUDE.md](CLAUDE.md) for architecture, conventions, and deployment
details.
