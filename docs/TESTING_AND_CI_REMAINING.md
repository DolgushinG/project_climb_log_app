# Тестирование и CI — что осталось

## Сделано

- Unit-тесты: utils, models, services (TrainingPlanGenerator, TrainingGamificationService)
- Widget-тесты: AICoachScreen, RegistrationStepper, SetSelectionCards, ErrorReportButton, TopNotificationBanner, error_report_modal, ClimbingLogLandingScreen, ResultEntryButton, **LoginScreen**, **RegistrationScreen**
- CI: `flutter analyze` + `flutter test` на push и pull_request
- Pre-commit: скрипт `scripts/pre-commit.sh`, хук активирован
- Coverage в CI: `flutter test --coverage`, артефакт `coverage/lcov.info` загружается в workflow run
- Integration-тесты (E2E): `integration_test/app_test.dart` — главный экран, табы, логин (new@gmail.com / password). Запуск локально: `flutter test integration_test -d <device>` (эмулятор/устройство)
- AuthService: абстракция для login/register (мокабельная в тестах)
- analysis_options: снижено количество замечаний до 0 (часть правил отключена/игнорируется)

---

## Что осталось

### 1. Тесты сервисов с HTTP

ClimbingLogService, ProfileService, AICoachService и др. — требуют мок `http.Client`:

- Внедрить абстракцию HTTP (или использовать `http/testing.dart`)
- Сложность: средняя

### 2. Ещё widget-тесты для экранов с зависимостями

- PlanSelectionScreen
- ClimbingLogAddScreen
- ClimbingLogScreen

Нужно мокать сервисы. Сложность: средняя.

### 3. Постепенное исправление игнорируемых диагностик

В `analysis_options.yaml` для части проблем выставлено `ignore`:

- `unused_field`, `unused_local_variable`, `unused_element`
- `deprecated_member_use` (MaterialStateProperty → WidgetStateProperty)
- `unnecessary_non_null_assertion`, `invalid_null_aware_operator`
- `must_be_immutable`, `dead_code`, `dead_null_aware_expression`

Можно постепенно убирать `ignore` и чинить код. Сложность: высокая (много файлов).

---

## Приоритеты

| Задача                    | Приоритет | Оценка |
|---------------------------|-----------|--------|
| Тесты сервисов с HTTP     | Средний   | 4–8 ч  |
| Исправление analyze       | Низкий    | по мере возможности |
