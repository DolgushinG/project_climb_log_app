#!/bin/bash
# Копирует premium/success и premium/fail в build/web/.
# Flutter build web не включает эти страницы — без них postMessage из iframe не работает.
# Вызывается в CI после flutter build web. Для локального serve — запустить после сборки:
#   flutter build web && ./scripts/copy_premium_pages.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build/web/premium/success" "$ROOT/build/web/premium/fail"
cp "$ROOT/web/premium/success/index.html" "$ROOT/build/web/premium/success/"
cp "$ROOT/web/premium/fail/index.html" "$ROOT/build/web/premium/fail/"
echo "Copied premium success/fail pages to build/web/"
