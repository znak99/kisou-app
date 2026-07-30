#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

echo "Building a production-config verification AAB."
echo "Do not upload it until release preparation configures an upload key."

flutter pub get
flutter build appbundle \
  --release \
  --flavor prod \
  --dart-define-from-file=config/prod.json
