# API: Упражнения и фиксация выполнения

Спецификация для бэкенда — каталог упражнений и запись выполненных.

> **Дополнение:** см. [BACKEND_EXERCISES_IMAGES_STRETCHING.md](./BACKEND_EXERCISES_IMAGES_STRETCHING.md) — картинки (`image_url`) и растяжка (category `stretching`, `muscle_groups`).

---

## 1. Уровни (grade → уровень)

| Грейд | Уровень |
|-------|---------|
| до 6c | `novice` (новичок) |
| 6c+ — 7b | `intermediate` (продвинутый) |
| 7c+ | `pro` (профи) |

---

## 2. Категории

- **SFP** — Специфическая физподготовка (висы, щипок, lock-off, тяга на финге)
- **OFP** — Общая физподготовка (подтяги, пресс, core, стабилизация)

---

## 3. Эндпоинты

### 3.1 Каталог упражнений

**`GET /api/climbing-logs/exercises`**

Query: `level=novice|intermediate|pro`, `category=sfp|ofp` (опционально)

**Response:**
```json
{
  "exercises": [
    {
      "id": "repeaters_7_13",
      "name": "Repeaters 7:13",
      "name_ru": "Репитеры 7:13",
      "category": "sfp",
      "level": "intermediate",
      "description": "7 сек вис / 13 сек отдых, 6 повторов. Выносливость.",
      "default_sets": 3,
      "default_reps": "6",
      "default_rest": "180s",
      "target_weight_optional": true
    },
    {
      "id": "max_hangs_3_5_7",
      "name": "Max Hangs 3-5-7",
      "name_ru": "Макс. висы 3-5-7",
      "category": "sfp",
      "level": "intermediate",
      "description": "Пиковая сила пальцев.",
      "default_sets": 3,
      "default_reps": "7",
      "default_rest": "180s",
      "target_weight_optional": false
    }
  ]
}
```

### 3.2 Сохранение выполнения

**`POST /api/climbing-logs/exercise-completions`**

**Request:**
```json
{
  "date": "2025-02-13",
  "exercise_id": "repeaters_7_13",
  "sets_done": 3,
  "weight_kg": 25.5,
  "notes": ""
}
```

**Response:** `201 Created` → `{"id": 1}`

### 3.3 История выполнений

**`GET /api/climbing-logs/exercise-completions`**

Query: `date=2025-02-13`, `period_days=7` (опц.)

**Response:**
```json
{
  "completions": [
    {
      "id": 1,
      "date": "2025-02-13",
      "exercise_id": "repeaters_7_13",
      "exercise_name": "Repeaters 7:13",
      "sets_done": 3,
      "weight_kg": 25.5
    }
  ]
}
```

### 3.4 Отмена выполнения (для снятия галочки)

**`DELETE /api/climbing-logs/exercise-completions/:id`**

Позволяет «снять галочку» в приложении. Если не реализовано — приложение при неудачном DELETE сохраняет состояние локально (при следующей загрузке с бэка галочка вернётся).

**Response:** `200` или `204`

> **Дополнение:** см. [BACKEND_EXERCISE_SKIPS.md](./BACKEND_EXERCISE_SKIPS.md) — пропуски упражнений (не могу выполнить).

---

## 4. Рекомендуемые упражнения для каталога

### SFP (новичок)

- Repeaters 7:13 (лёгкий вес)
- Щипок 40 мм
- Dead Hang на перекладине

### SFP (продвинутый)

- Max Hangs 3-5-7
- Power Pulls
- Pinch Lifting (блок)
- Offset Pull-ups

### SFP (профи)

- Max Hangs 3-5-7 (макс. вес)
- One-arm block pulls
- Lock-off 90° работа

### OFP (все уровни)

- Подтягивания
- Пресс (планка, подъёмы ног)
- Растяжка предплечий
- Стабильность плеча

---

## 5. Состояние приложения (интеграция с API)

- **ExerciseCompletionScreen** — упражнения из плана (СФП) + ОФП по уровню с чекбоксами
- **TrainingPlanScreen** — блок «ОФП по твоему уровню» со списком + кнопка в «Выполнить упражнения»
- **GET /exercises?level=...&category=ofp** — каталог ОФП по уровню (novice/intermediate/pro)
- **GET /exercise-completions?date=YYYY-MM-DD** — загрузка выполнений за день
- **POST /exercise-completions** — сохранение при отметке «выполнил»
- **DELETE /exercise-completions/:id** — снятие отметки (опционально на бэке)
- Fallback на SharedPreferences при ошибке API или отсутствии сети
- Каждый drill в плане имеет `exercise_id` для соответствия бэкенду: `max_hangs_3_5_7`, `power_pulls`, `pinch_lifting`, `offset_pull_ups`, `repeaters_7_13`
