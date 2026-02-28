# Backend API для модуля «Тестирование силы» (Strength Testing)

Модуль «Тестирование» во вкладке «Тренировки» позволяет пользователю замерять силу пальцев, щипка, тяги и lock-off. Включает систему рангов (Climbing Archetypes) и ачивок. Данные хранятся локально; для синхронизации и аналитики требуется бэкенд.

---

## Система рангов (Strength Tiers)

Ранг вычисляется по среднему % относительной силы по всем заполненным тестам.

| Ур. | Архетип           | % отн. силы |
|-----|-------------------|-------------|
| 1   | Grasshopper       | < 30%       |
| 2   | Stone Gecko       | 30–50%      |
| 3   | Mountain Lynx     | 50–70%      |
| 4   | Gravity Defier    | 70–90%      |
| 5   | Apex Predator     | > 90%       |

## Ачивки (Badges)

| ID              | Название         | Условие                          |
|-----------------|------------------|----------------------------------|
| crab_claws      | Клешни Краба     | Щипок ≥ 40% BW                   |
| steel_crimp     | Стальной КРИМП   | Тяга 20 мм одной рукой ≥ 60% BW  |
| hauler          | Тягач            | Подтягивание с +50% BW           |
| balance_of_power| Баланс Силы      | Асимметрия < 3%                  |
| iron_lock       | Железный Блок    | Lock-off 90° ≥ 30 сек            |

---

## Что ожидается от бэкенда

### 1. Хранение веса тела (Body Weight)

**Вариант A: расширение профиля**

- Добавить в `UserProfile` поле `body_weight` (float, кг).
- Эндпоинты: `GET /api/profile` должен возвращать `body_weight`, `POST /api/profile/edit` — принимать его.

**Вариант B: отдельный эндпоинт**

- `GET /api/climbing-logs/strength-test-settings` → `{ "body_weight": 72.5 }`
- `PUT /api/climbing-logs/strength-test-settings` → `{ "body_weight": 72.5 }`

---

### 2. Сохранение результатов тестов

**Эндпоинт:** `POST /api/climbing-logs/strength-tests`

**Тело запроса:**
```json
{
  "date": "2025-02-13",
  "body_weight_kg": 72,
  "finger_isometrics": {
    "grip_type": "half_crimp",
    "left_kg": 25,
    "right_kg": 24
  },
  "pinch_grip": {
    "block_width_mm": 40,
    "max_weight_kg": 18
  },
  "pulling_power": {
    "added_weight_kg": 15,
    "reps": 1,
    "estimated_1rm_kg": 87,
    "relative_strength_pct": 120.8
  },
  "lock_off_sec": 32,
  "current_rank": "Mountain Lynx",
  "unlocked_badges": ["crab_claws", "hauler"]
}
```

**Поля:**
- `date` — дата теста (YYYY-MM-DD)
- `body_weight_kg` — вес тела на момент теста
- `finger_isometrics` — опционально
  - `grip_type`: `"half_crimp"` | `"open"`
  - `left_kg`, `right_kg` — вес в кг
- `pinch_grip` — опционально
  - `block_width_mm`: 40 | 60 | 80
  - `max_weight_kg` — максимальный вес
- `pulling_power` — опционально
  - `added_weight_kg` — дополнительный вес на поясе
  - `reps` — количество повторений (1 для 1RM)
  - `estimated_1rm_kg` — расчётный 1RM (body_weight + added_weight при reps=1, или по формуле Epley)
  - `relative_strength_pct` — (1RM / body_weight) * 100
- `lock_off_sec` — опционально, удержание Lock-off 90° в секундах
- `current_rank` — опционально, текущий архетип
- `unlocked_badges` — опционально, массив id ачивок

**Response:** `201 Created` с `{ "id": 123 }` или `200 OK` при обновлении.

---

### 3. История результатов для графиков

**Эндпоинт:** `GET /api/climbing-logs/strength-tests`

**Query:**
- `period_days`: 30 | 90 | 365 (по умолчанию 90)
- `test_type`: `finger` | `pinch` | `pulling` (опционально — фильтр)

**Response:**
```json
{
  "tests": [
    {
      "id": 1,
      "date": "2025-02-13",
      "body_weight_kg": 72,
      "finger_left_kg": 25,
      "finger_right_kg": 24,
      "finger_grip_type": "half_crimp",
      "pinch_40mm_kg": 18,
      "pinch_60mm_kg": null,
      "pinch_80mm_kg": null,
      "pulling_1rm_kg": 87,
      "pulling_relative_strength_pct": 120.8
    }
  ]
}
```

---

### 4. Асимметрия (расчёт на фронте или бэке)

- Фронт уже считает `(max - min) / max * 100`.
- Бэкенд может дополнительно сохранять `asymmetry_pct` и генерировать рекомендации в `/recommendations`:
  - `"Разница между руками > 10%. Рекомендуем эксцентрику для слабой стороны."`

---

### 5. Рекомендации (расширение)

Текущий `GET /api/climbing-logs/recommendations` может дополняться типами:

- `asymmetry` — при разнице левая/правая > 10%
- `pulling_weak` — при relative strength < 100%
- `finger_progress` — при росте показателей по истории

---

## Формулы (для бэкенда при валидации)

- **Relative Strength (тяга):** `(body_weight + added_weight) / body_weight * 100` при 1 повторении.
- **1RM из N повторений (Epley):** `total_weight * (1 + reps / 30)`
- **% от веса (пальцы):** `finger_kg / body_weight * 100`
- **Асимметрия:** `|left - right| / max(left, right) * 100`

---

### 6. Leaderboard «Топ недели»

**Эндпоинт:** `GET /api/climbing-logs/strength-leaderboard`

**Query:**
- `period`: `week` | `month`
- `weight_range_kg`: `"60-70"` или `min_weight`, `max_weight` — фильтр по весовому диапазону пользователя

**Response:**
```json
{
  "leaderboard": [
    {
      "user_id": 123,
      "display_name": "Иван Иванов",
      "avatar_url": "...",
      "average_strength_pct": 72.5,
      "rank": 1,
      "weight_kg": 68
    }
  ],
  "user_position": 15,
  "total_participants": 120
}
```

**display_name:** обязательно полное имя и фамилия (например, «Иван Иванов»), не инициалы. В приложении при переполнении обрезается с многоточием (`overflow: ellipsis`).

**Расширение для «кто сколько жмёт»:** при необходимости в каждый элемент `leaderboard` можно добавить:
- `finger_left_kg`, `finger_right_kg`
- `pinch_kg`
- `pull_added_kg` или `pull_1rm_pct`

Тогда в приложении можно выводить подробную таблицу по каждому участнику.

---

---

### 7. Генератор плана (локальный алгоритм)

План генерируется на клиенте по алгоритму «слабое звено»:

| Проблема         | Протокол                          |
|------------------|-----------------------------------|
| Пальцы < Спина   | Max Hangs (3-5-7)                 |
| Спина < Пальцы   | Power Pulls                       |
| Щипок < Актив    | Pinch Lifting                     |
| Асимметрия > 10% | Offset Pull-ups (Unilateral)      |

**Структура JSON плана для API:**
```json
{
  "focus_area": "pinch_and_asymmetry",
  "weeks_plan": 4,
  "sessions_per_week": 2,
  "target_grade": "7b",
  "coach_tip": "Твой хват...",
  "drills": [
    {
      "name": "One-arm Block Pulls",
      "target_weight_kg": 22.5,
      "sets": 5,
      "reps": "5s hold",
      "rest": "180s"
    }
  ]
}
```

---

## Безопасность

- Все эндпоинты под авторизацией `Authorization: Bearer <token>`.
- `body_weight_kg` — валидация: 30–200 кг.
- `reps` — 1–10 для pulling.
- `block_width_mm` — только 40, 60, 80.
