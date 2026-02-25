#!/bin/bash
# Синхронизирует ?v= в web/index.html и manifest.json с build-number из pubspec.yaml.
# Entry-point файлы (index.html, manifest, service worker) должны не кэшироваться (см. docs/WEB_CACHE_UPDATE.md).
# Запускать перед `flutter build web`, например:
#   ./scripts/web_version_bump.sh && flutter build web --no-web-resources-cdn

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUBSPEC="$ROOT/pubspec.yaml"
INDEX="$ROOT/web/index.html"
MANIFEST="$ROOT/web/manifest.json"

# Извлекаем version (например "1.0.0+3") и берём часть после +
BUILD=$(grep -E '^version:' "$PUBSPEC" | sed -E 's/version: *([^+]*)\+?([0-9]*).*/\2/')
if [ -z "$BUILD" ] || [ "$BUILD" = "0" ]; then
  BUILD=1
fi

# Заменяем ?v=ЧИСЛО в flutter_bootstrap.js (macOS и Linux)
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/flutter_bootstrap\.js?v=[0-9]*/flutter_bootstrap.js?v=$BUILD/" "$INDEX"
  # manifest.json: start_url с ?v= — при открытии PWA браузер получит «новый» URL (идемпотентно)
  if [ -f "$MANIFEST" ]; then
    sed -i '' 's/"start_url"[[:space:]]*:[[:space:]]*"\.[^"]*"/"start_url":".\/?v='$BUILD'"/' "$MANIFEST"
  fi
else
  sed -i "s/flutter_bootstrap\.js?v=[0-9]*/flutter_bootstrap.js?v=$BUILD/" "$INDEX"
  if [ -f "$MANIFEST" ]; then
    sed -i 's/"start_url"[[:space:]]*:[[:space:]]*"\.[^"]*"/"start_url":".\/?v='$BUILD'"/' "$MANIFEST"
  fi
fi

echo "web/index.html: flutter_bootstrap.js?v=$BUILD"
[ -f "$MANIFEST" ] && echo "web/manifest.json: start_url=./?v=$BUILD"
