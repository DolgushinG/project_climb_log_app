#!/bin/sh
# Запуск всех E2E тестов с Allure отчётом.
# Сборка web + serve поднимает Playwright (webServer в playwright.config.ts).
# Использование: ./scripts/e2e-allure.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
flutter build web --release --dart-define=USE_DEV_API=true --dart-define=E2E_MODE=true --no-web-resources-cdn --web-renderer html
cd e2e
BASE_URL="${BASE_URL:-http://localhost:8080}" ALLURE=1 npx playwright test
allure generate allure-results --clean -o allure-report
echo "Allure report generated. Opening..."
allure open allure-report
