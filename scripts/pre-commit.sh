#!/bin/sh
# Pre-commit hook: run Flutter analyze, unit tests, and E2E tests before commit.
# Install: ln -sf ../../scripts/pre-commit.sh .git/hooks/pre-commit
# Требует для E2E: flutter build web, serve на :8080, allure CLI.
set -e
echo "Running flutter analyze..."
flutter analyze
echo "Running flutter test..."
flutter test --no-pub
if [ "${SKIP_E2E}" = "1" ]; then
  echo "Skipping E2E (SKIP_E2E=1)"
else
  echo "Running E2E tests (Allure)..."
  ./scripts/e2e-allure.sh
fi
