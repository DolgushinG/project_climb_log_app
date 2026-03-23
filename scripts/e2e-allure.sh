#!/bin/sh
# Запуск всех E2E тестов с Allure отчётом.
# Требует: сборка web (flutter build web) и serve на :8080.
# Использование: ./scripts/e2e-allure.sh
set -e
cd "$(dirname "$0")/../e2e"
BASE_URL="${BASE_URL:-http://localhost:8080}" ALLURE=1 npx playwright test
allure generate allure-results --clean -o allure-report
echo "Allure report generated. Opening..."
allure open allure-report
