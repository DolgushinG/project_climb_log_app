# API трекера тренировок Climbing Log (Flutter)

Документация API для трекера лазательных сессий. Flutter‑приложение использует **Bearer token** (без привязки Telegram).

## Эндпоинты

| Метод | URL | Auth | Описание |
|-------|-----|------|----------|
| GET | /api/climbing-logs/grades | — | Список грейдов |
| POST | /api/climbing-logs | Bearer | Сохранить сессию |
| PUT | /api/climbing-logs/{id} | Bearer | Редактировать сессию |
| DELETE | /api/climbing-logs/{id} | Bearer | Удалить сессию |
| GET | /api/climbing-logs/used-gyms | Bearer | Залы, где уже тренировались |
| GET | /api/climbing-logs/progress | Bearer | Прогресс |
| GET | /api/climbing-logs/history | Bearer | История сессий (нужны id, gym_id) |
| GET | /api/search-gyms?query= | — | Поиск залов |

## Модели (lib/models/ClimbingLog.dart)

- `RouteEntry`, `ClimbingSessionRequest` — для POST сессии
- `ClimbingProgress` — прогресс (maxGrade, progressPercentage, grades)
- `HistorySession`, `HistoryRoute` — история

## Сервис (lib/services/ClimbingLogService.dart)

- `getGrades()` / `getGradesWithGroups()`
- `saveSession(ClimbingSessionRequest)`
- `getProgress()`
- `getHistory()`

Поиск залов — `searchGyms(query)` в `GymService`.
