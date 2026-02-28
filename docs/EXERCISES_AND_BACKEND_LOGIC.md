# Упражнения и логика выдачи бэкендом

Описание всех типов упражнений в приложении и как их выдаёт бэкенд (или локальный генератор).

---

## 1. Три источника упражнений

На экране «Выполнить упражнения» пользователь видит три блока:

| Блок | Источник | API / логика |
|------|----------|--------------|
| **План (СФП)** | Локально + бэкенд | Генерируется в Flutter по замерам или загружается с бэка |
| **ОФП по уровню** | Бэкенд | `GET /api/climbing-logs/exercises?level=...&category=ofp` |
| **Растяжка** | Бэкенд | `GET /api/climbing-logs/exercises?level=...&category=stretching` |

---

## 2. Категории упражнений

### SFP (Специфическая физподготовка)

Упражнения на пальцы, щипок, lock-off, тягу на фингерборде. Выдаются **внутри плана** как `TrainingDrill` — не через каталог exercises.

### OFP (Общая физподготовка)

Подтягивания, пресс, core, стабилизация. Выдаются через **GET /exercises?category=ofp**.

### Stretching (Растяжка)

Растяжка после ОФП. Выдаются через **GET /exercises?category=stretching**.

---

## 3. Определение уровня пользователя

Уровень (`novice`, `intermediate`, `pro`) определяет, какие ОФП и растяжка показываются.

**Источники уровня (по приоритету):**

1. **Бэкенд:** `GET /api/climbing-logs/strength-level` → поле `level`
2. **Локально:** по метрикам из замеров — `_computeLevel(StrengthMetrics)`

**Локальная формула (средняя сила в % от веса):**

- **novice** — < 40%
- **intermediate** — 40–65%
- **pro** — ≥ 65%

Средняя считается по: пальцы, щипок, тяга 1RM%, lock-off (сек/30×100).

**Fallback:** если по OFP ничего не пришло, пробуем `level=intermediate`.

---

## 4. План (СФП) — логика генерации

План генерируется **локально** в `TrainingPlanGenerator` на основе замеров (`StrengthMetrics`).

### 4.1 Анализ слабого звена (`analyzeWeakLink`)

| Условие | Результат |
|--------|-----------|
| Пальцы < 50% от спины | `fingersWeak` → протокол `max_hangs` |
| Спина < 1.5× пальцев | `pullWeak` → протокол `power_pulls` |
| Щипок < 70% от пальцев | `pinchWeak` → протокол `pinch_lifting` |
| Асимметрия Л/П > 10% | `asymmetryHigh` → протокол `unilateral` |

### 4.2 Маппинг протоколов → упражнения (drills)

| Протокол | Упражнение (TrainingDrill) | exercise_id |
|----------|---------------------------|-------------|
| max_hangs | 3-5-7 Protocol (Max Hangs) | `max_hangs_3_5_7` |
| power_pulls | Power Pulls (Взрывные подтягивания) | `power_pulls` |
| pinch_lifting | One-arm Block Pulls (Pinch Lifting) | `pinch_lifting` |
| unilateral | Offset Pull-ups | `offset_pull_ups` |
| (если ни одного) | Repeaters (7:13) | `repeaters_7_13` |

### 4.3 Структура TrainingDrill (из плана)

```json
{
  "name": "3-5-7 Protocol (Max Hangs)",
  "target_weight_kg": 25.5,
  "sets": 3,
  "reps": "3 сек тяга / 5 сек отдых / 7 повторов",
  "rest": "180s",
  "hint": "Максимальные висы на фингерборде...",
  "exercise_id": "max_hangs_3_5_7"
}
```

### 4.4 Сохранение плана на бэк

**POST /api/climbing-logs/training-plans** — опционально. Сейчас план создаётся в Flutter и может быть отправлен на бэк для истории. В экране выполнения план **генерируется заново** при каждой загрузке.

---

## 5. ОФП — логика выдачи бэкендом

**GET /api/climbing-logs/exercises?level=novice|intermediate|pro&category=ofp**

Бэкенд возвращает список упражнений уровня пользователя. Примеры: подтягивания, пресс, core, стабилизация плеча.

**Структура CatalogExercise (OFP):**

| Поле | Тип | Описание |
|------|-----|----------|
| id | string | Уникальный id (для exercise-completions) |
| name | string | Название (EN) |
| name_ru | string? | Название (RU) |
| category | "ofp" | |
| level | string | novice / intermediate / pro |
| description | string? | Что делать |
| image_url | string? | URL картинки |
| muscle_groups | string[] | back, core, forearms, shoulders, chest, legs |
| default_sets | int | Подходов |
| default_reps | string | Повторения / время |
| default_rest | string | Отдых (180s, 90s, 2m) |
| target_weight_optional | bool | Нужен ли вес |

---

## 6. Растяжка — логика выдачи

**GET /api/climbing-logs/exercises?level=...&category=stretching**

### 6.1 Фильтрация по muscle_groups

Если в ОФП есть упражнения с `muscle_groups`, растяжка **фильтруется** по пересечению:

- Собираем все `muscle_groups` из ОФП-упражнений
- Показываем только те растяжки, у которых `muscle_groups` пустой или пересекается с ОФП

Пример: ОФП = Pull-ups (back, forearms) → растяжка с back или forearms.

Если у ОФП нет muscle_groups — показываем все растяжки уровня.

### 6.2 Fallback уровня

Если по `level` растяжка пустая и level ≠ intermediate — запрашиваем `level=intermediate`.

---

## 7. Сохранение выполнения

**POST /api/climbing-logs/exercise-completions**

```json
{
  "date": "2025-02-13",
  "exercise_id": "repeaters_7_13",
  "sets_done": 3,
  "weight_kg": 25.5,
  "notes": ""
}
```

`exercise_id` берётся из:
- плана (СФП): `TrainingDrill.exerciseId` (max_hangs_3_5_7, power_pulls, pinch_lifting, offset_pull_ups, repeaters_7_13)
- ОФП / растяжка: `CatalogExercise.id`

**DELETE /api/climbing-logs/exercise-completions/:id** — снятие галочки.

---

## 8. Сводная таблица exercise_id в плане

| exercise_id | Упражнение |
|-------------|------------|
| max_hangs_3_5_7 | 3-5-7 Protocol (Max Hangs) |
| power_pulls | Power Pulls |
| pinch_lifting | Pinch Lifting (щипковый блок) |
| offset_pull_ups | Offset Pull-ups |
| repeaters_7_13 | Repeaters (7:13) |

Бэкенд должен иметь в каталоге упражнения с такими id, чтобы GET exercise-completions и отчётность работали корректно. Каталог **GET /exercises** для SFP используется при необходимости (например, для TrainingPlanScreen), но план на экране выполнения собирается локально.

---

## 9. Кэш и fallback

- **Кэш экрана:** план, ОФП, растяжка, completed, level сохраняются в SharedPreferences по ключу `exercise_completion_screen_cache_{date}`.
- **Загрузка:** сначала из кэша, затем фоновый запрос к API с обновлением UI.
- **Completed:** при ошибке API — fallback на локальный JSON в SharedPreferences.
