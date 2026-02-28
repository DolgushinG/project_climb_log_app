# Backend: пропорциональная нагрузка ОФП

Спецификация дозирования ОФП (реализовано на бэкенде).

---

## 1. Конфиг (config/climbing_exercises.php)

| Параметр | Описание |
|----------|----------|
| `ofp_default_limit` | Лимиты по уровню: novice 5, intermediate 6, pro 7 |
| `ofp_session_type_limits` | short (5), standard (7), full (без лимита) |
| `ofp_priority_ids` | Приоритетные упражнения (подтягивания, лодочка, планка и т.д.) |

---

## 2. API GET /api/climbing-logs/exercises

Для ОФП (`category=ofp`) поддерживаются параметры:

| Параметр | Описание |
|----------|----------|
| `limit` | Жёсткий лимит (1–50), например `limit=6` |
| `session_type` | `short` (5 упр.), `standard` (7 упр.), `full` — без ограничения |

**Если параметры не заданы** — используется лимит по уровню (5–7 упражнений).

**Логика выбора на бэке:**
1. Сначала добавляются упражнения из `ofp_priority_ids`
2. Оставшиеся слоты заполняются упражнениями с разными `muscle_groups` для лучшего покрытия

---

## 3. Примеры запросов

| Запрос | Результат |
|--------|-----------|
| `GET /exercises?level=intermediate&category=ofp` | до 6 упражнений по умолчанию |
| `GET /exercises?level=intermediate&category=ofp&session_type=short` | 5 упражнений (≈25 мин) |
| `GET /exercises?level=intermediate&category=ofp&session_type=standard` | 7 упражнений |
| `GET /exercises?level=intermediate&category=ofp&limit=4` | ровно 4 упражнения |

---

## 4. Отдых между подходами

Отдых задаётся в `default_rest` каждого упражнения. Приложение парсит форматы: `180s`, `90s`, `2m`. Бэкенд возвращает своё значение в ответе — отдых не фиксирован.

---

## 5. Интеграция Flutter

`StrengthTestApiService.getExercises()` передаёт `level` и `category`. Бэкенд автоматически применяет дозирование для `category=ofp`.

Опциональные параметры (уже добавлены): `sessionType` (`short`/`standard`/`full`), `limit` (1–50) — для режимов «короткая / полная тренировка».
