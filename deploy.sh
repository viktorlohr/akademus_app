#!/usr/bin/env bash
# Builds the main app and the quiz admin page (nested under /edit-quiz, see
# firebase.json's rewrite for that path) into build/web, then deploys both
# with one `firebase deploy`. Order matters: the main app owns build/web and
# must build first, or its build step would wipe the nested admin output.
set -euo pipefail

flutter build web

flutter build web \
  --target=lib/admin_main.dart \
  --base-href /edit-quiz/ \
  --output=build/web/edit-quiz

firebase deploy
