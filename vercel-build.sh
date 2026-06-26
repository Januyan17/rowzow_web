#!/usr/bin/env bash
set -euo pipefail

git clone https://github.com/flutter/flutter.git -b stable --depth 1 _flutter
export PATH="$PWD/_flutter/bin:$PATH"

flutter doctor
flutter pub get
flutter build web --release \
  --dart-define=APP_FLAVOR="${APP_FLAVOR:-prod}" \
  --dart-define=APP_NAME="${APP_NAME:-Rowzow Gaming Center}" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:?SUPABASE_URL env var is required}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY env var is required}" \
  --dart-define=APP_DEBUG_LOG="${APP_DEBUG_LOG:-false}"
