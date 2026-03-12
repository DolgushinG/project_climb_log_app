#!/bin/sh
# Pre-commit hook: run Flutter analyze and tests before commit.
# Install: ln -sf ../../scripts/pre-commit.sh .git/hooks/pre-commit
set -e
echo "Running flutter analyze..."
flutter analyze
echo "Running flutter test..."
flutter test --no-pub
