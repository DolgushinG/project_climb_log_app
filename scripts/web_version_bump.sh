#!/bin/bash
# Синхронизирует ?v= в web/index.html с build-number из pubspec.yaml.
# Запускать перед `flutter build web`, например:
#   ./scripts/web_version_bump.sh && flutter build web

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUBSPEC="$ROOT/pubspec.yaml"
INDEX="$ROOT/web/index.html"

# Извлекаем version (например "1.0.0+3") и берём часть после +
BUILD=$(grep -E '^version:' "$PUBSPEC" | sed -E 's/version: *([^+]*)\+?([0-9]*).*/\2/')
if [ -z "$BUILD" ] || [ "$BUILD" = "0" ]; then
  BUILD=1
fi

# Заменяем ?v=ЧИСЛО в flutter_bootstrap.js (macOS и Linux)
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/flutter_bootstrap\.js?v=[0-9]*/flutter_bootstrap.js?v=$BUILD/" "$INDEX"
else
  sed -i "s/flutter_bootstrap\.js?v=[0-9]*/flutter_bootstrap.js?v=$BUILD/" "$INDEX"
fi

echo "web/index.html: flutter_bootstrap.js?v=$BUILD"
