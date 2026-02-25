#!/bin/bash
# Удаляет ссылки на source map из flutter.js и flutter_bootstrap.js.
# Flutter не генерирует flutter.js.map в release build, но оставляет //# sourceMappingURL=flutter.js.map.
# Браузер запрашивает .map, получает 404 (HTML), парсит как JSON → SyntaxError: Unrecognized token '<'.
# Запускать после `flutter build web`, например:
#   flutter build web && ./scripts/web_strip_sourcemaps.sh

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_WEB="$ROOT/build/web"

for f in flutter.js flutter_bootstrap.js; do
  path="$BUILD_WEB/$f"
  if [ -f "$path" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' '/^[[:space:]]*\/\/# sourceMappingURL=/d' "$path"
    else
      sed -i '/^[[:space:]]*\/\/# sourceMappingURL=/d' "$path"
    fi
    echo "Removed sourceMappingURL from $f"
  fi
done
