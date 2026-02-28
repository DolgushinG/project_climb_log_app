# Сверка Climbing Log API ↔ Flutter

Сводка эндпоинтов и проверка реализации в приложении.

---

## Базовые (трекинг сессий)

| Метод | URL | Auth | Flutter | Метод сервиса | Где используется |
|-------|-----|------|---------|---------------|------------------|
| GET | `/api/climbing-logs/grades` | — | ✅ | `ClimbingLogService.getGrades()` / `getGradesWithGroups()` | Выбор грейдов |
| POST | `/api/climbing-logs` | Bearer | ✅ | `ClimbingLogService.saveSession()` | `ClimbingLogAddScreen` — сохранение сессии |
| GET | `/api/climbing-logs/progress` | Bearer | ✅ | `ClimbingLogService.getProgress()` | `ClimbingLogProgressScreen` |
| GET | `/api/climbing-logs/summary` | Bearer | ✅ | `ClimbingLogService.getSummary(period)` | `ClimbingLogSummaryScreen` |
| GET | `/api/climbing-logs/statistics` | Bearer | ✅ | `ClimbingLogService.getStatistics(groupBy, periodDays)` | `ClimbingLogSummaryScreen` — графики |
| GET | `/api/climbing-logs/recommendations` | Bearer | ✅ | `ClimbingLogService.getRecommendations()` | `ClimbingLogSummaryScreen` |
| GET | `/api/climbing-logs/history` | Bearer | ✅ | `ClimbingLogService.getHistory()` | `ClimbingLogHistoryScreen`, `getUsedGyms` fallback |
| GET | `/api/climbing-logs/used-gyms` | Bearer | ✅ | `ClimbingLogService.getUsedGyms()` | `ClimbingLogAddScreen` — подсказка залов |
| GET | `/api/climbing-logs/stats` | Bearer | ⚠️ | — | **Не используется.** Flutter вызывает `statistics`, не `stats` |
| PUT | `/api/climbing-logs/{id}` | Bearer | ✅ | `ClimbingLogService.updateSession(id, request)` | `ClimbingLogAddScreen` — редактирование |
| DELETE | `/api/climbing-logs/{id}` | Bearer | ✅ | `ClimbingLogService.deleteSession(id)` | `ClimbingLogHistoryScreen` |

---

## Замеры силы

| Метод | URL | Auth | Flutter | Метод сервиса | Где используется |
|-------|-----|------|---------|---------------|------------------|
| GET | `/api/climbing-logs/strength-tests` | Bearer | ✅ | `StrengthTestApiService.getStrengthTestsHistory()` | `ClimbingLogTestingScreen`, `ClimbingLogProgressScreen`, `StrengthHistoryScreen` |
| POST | `/api/climbing-logs/strength-tests` | Bearer | ✅ | `StrengthTestApiService.saveStrengthTest()` | `ClimbingLogTestingScreen` — сохранение замера |
| GET | `/api/climbing-logs/strength-test-settings` | Bearer | ✅ | `StrengthTestApiService.getBodyWeight()` | `ClimbingLogTestingScreen` |
| PUT | `/api/climbing-logs/strength-test-settings` | Bearer | ✅ | `StrengthTestApiService.saveBodyWeight()` | `ClimbingLogTestingScreen` |
| GET | `/api/climbing-logs/strength-leaderboard` | Bearer | ✅ | `StrengthTestApiService.getLeaderboard()` | `ClimbingLogTestingScreen` — топ недели |
| GET | `/api/climbing-logs/strength-level` | Bearer | ✅ | `StrengthTestApiService.getStrengthLevel()` | `ExerciseCompletionScreen`, `TrainingPlanScreen` — уровень для ОФП |

---

## Геймификация и планы

| Метод | URL | Auth | Flutter | Метод сервиса | Где используется |
|-------|-----|------|---------|---------------|------------------|
| GET | `/api/climbing-logs/gamification` | Bearer | ✅ | `StrengthTestApiService.getGamification()` | `ClimbingLogSummaryScreen` — XP, streak |
| POST | `/api/climbing-logs/session-xp` | Bearer | ✅ | `StrengthTestApiService.addSessionXp()` | `ClimbingLogAddScreen` — после сохранения сессии |
| POST | `/api/climbing-logs/training-plans` | Bearer | ✅ | `StrengthTestApiService.saveTrainingPlan()` | `TrainingPlanScreen` — при открытии экрана |

---

## Упражнения

| Метод | URL | Auth | Flutter | Метод сервиса | Где используется |
|-------|-----|------|---------|---------------|------------------|
| GET | `/api/climbing-logs/exercises` | — * | ✅ | `StrengthTestApiService.getExercises(level, category)` | `ExerciseCompletionScreen`, `TrainingPlanScreen` — ОФП по уровню |
| GET | `/api/climbing-logs/exercise-completions` | Bearer | ✅ | `StrengthTestApiService.getExerciseCompletions(date)` | `ExerciseCompletionScreen` |
| POST | `/api/climbing-logs/exercise-completions` | Bearer | ✅ | `StrengthTestApiService.saveExerciseCompletion()` | `ExerciseCompletionScreen` — отметка «выполнил» |
| DELETE | `/api/climbing-logs/exercise-completions/{id}` | Bearer | ✅ | `StrengthTestApiService.deleteExerciseCompletion(id)` | `ExerciseCompletionScreen` — снятие отметки |

\* В сводке указано Auth «—», Flutter отправляет Bearer. Бэкенд принимает оба варианта.

---

## Дополнительные детали

### Уровни (strength-level) — используется во Flutter

| Tier | level | Метки в UI |
|------|-------|------------|
| 0 | `novice` | новичок |
| 1 | `novice_plus` | новичок+ |
| 2 | `intermediate` | продвинутый |
| 3 | `intermediate_plus` | продвинутый+ |
| 4 | `pro` | профи |

### Каталог упражнений

- `level`: `novice`, `novice_plus`, `intermediate`, `intermediate_plus`, `pro`
- `category`: `sfp`, `ofp`
- Fallback: при пустом ответе для уровня `pro` (и др.) — повторный запрос с `intermediate`

### Отсутствующие эндпоинты

| Эндпоинт | Статус |
|---------|--------|
| `GET /api/climbing-logs/training-plans` | ❌ Нет в бэкенде. Flutter генерирует план локально и только POST-ит. |
| `GET /api/climbing-logs/stats` | ⚠️ Legacy. Flutter использует `statistics`, не `stats`. |

---

## Резюме

- **Реализовано:** Все основные эндпоинты из сводки (кроме `stats`).
- **strength-level:** Интегрирован в `ExerciseCompletionScreen` и `TrainingPlanScreen` для запроса ОФП.
- **Fallback:** При ошибке или отсутствии `strength-level` используется локальный расчёт по замерам (`_computeLevel`).
- **Не реализовано:** `GET /training-plans` (список планов) — на бэке отсутствует.
