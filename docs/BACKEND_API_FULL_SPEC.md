# Полная спецификация API: что должен отдавать бэкенд

Сводный документ по всем модулям приложения, связанным с тренировками, тестированием силы и геймификацией.

> **Текущее состояние:** Вес и замеры сохраняются **только локально** (SharedPreferences + история сессий). Бэкенд не интегрирован. После реализации эндпоинтов — синхронизация между устройствами и доступ к истории с любого устройства.

---

## 1. Тренировки (Climbing Log) — уже есть

### `GET /api/climbing-logs/summary`
```json
{
  "total_sessions": 42,
  "total_routes": 312,
  "current_streak": 5,
  "max_streak": 12,
  "sessions_this_week": 3,
  "sessions_this_month": 12,
  "routes_this_week": 28,
  "routes_this_month": 95,
  "max_grade": "7A",
  "progress_percentage": 65,
  "favorite_gym_id": 5,
  "favorite_gym_name": "Скалалон"
}
```

### `GET /api/climbing-logs/statistics`
Query: `group_by=day|week|month`, `period_days=30|90`
```json
{
  "labels": ["01.01", "08.01"],
  "sessions": [2, 4],
  "routes": [18, 35],
  "grades_breakdown": [{"grade": "6B", "count": 45}]
}
```

### `GET /api/climbing-logs/recommendations`
```json
{
  "recommendations": [
    {"type": "streak", "text": "...", "priority": 1},
    {"type": "next_grade", "text": "...", "priority": 2},
    {"type": "asymmetry", "text": "Разница между руками > 10%...", "priority": 3},
    {"type": "pulling_weak", "text": "...", "priority": 4}
  ]
}
```

### `POST /api/climbing-logs` — сохранение сессии
### `GET /api/climbing-logs/grades`
### `GET /api/climbing-logs/history`
### `GET /api/climbing-logs/used-gyms`

---

## 2. Тестирование силы (Strength Testing)

### 2.1 Вес тела

**Вариант A:** расширить профиль  
`GET /api/profile` → добавить `"body_weight": 72.5`  
`POST /api/profile/edit` → принимать `body_weight`

**Вариант B:** отдельный эндпоинт  
`GET /api/climbing-logs/strength-test-settings` → `{"body_weight": 72.5}`  
`PUT /api/climbing-logs/strength-test-settings` → `{"body_weight": 72.5}`

---

### 2.2 Сохранение результатов тестов

**`POST /api/climbing-logs/strength-tests`**

**Request:**
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

**Response:** `201 Created` → `{"id": 123}`

---

### 2.3 История замеров (графики прогресса)

**`GET /api/climbing-logs/strength-tests`**

Query: `period_days=30|90|365`, `test_type=finger|pinch|pulling` (опц.)

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
      "pulling_relative_strength_pct": 120.8,
      "lock_off_sec": 32,
      "asymmetry_pct": 4.2
    }
  ]
}
```

---

### 2.4 Leaderboard «Топ недели»

**`GET /api/climbing-logs/strength-leaderboard`**

Query: `period=week|month`, `weight_range_kg=60-70` или `min_weight`, `max_weight`

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

`display_name` — обязательно полное имя и фамилия (не инициалы «т. т.»). В UI при переполнении — ellipsis.

---

## 3. Геймификация (XP, Streak)

Сейчас хранится локально. Для синхронизации между устройствами:

### 3.1 Сохранение XP при тренировке

**Вариант:** расширить ответ `POST /api/climbing-logs`  
Или отдельный вызов после сохранения сессии:

**`POST /api/climbing-logs/session-xp`** (или включить в response `saveSession`)

**Request:** `{"session_id": 123}` (если сессия уже создана)  
**Response:** `{"xp_gained": 50, "total_xp": 1250}`

### 3.2 Получение XP и Streak на дашборд

**`GET /api/climbing-logs/gamification`**

**Response:**
```json
{
  "total_xp": 1250,
  "streak_days": 5,
  "last_session_date": "2025-02-11",
  "recovery_status": "optimal",
  "boss_fight_due": false,
  "last_measure_date": "2025-02-01"
}
```

---

## 4. Генератор плана тренировок

План генерируется на клиенте. Для синхронизации и аналитики можно сохранять на бэке:

**`POST /api/climbing-logs/training-plans`**

**Request:**
```json
{
  "focus_area": "pinch_and_asymmetry",
  "weeks_plan": 4,
  "sessions_per_week": 2,
  "target_grade": "7b",
  "coach_tip": "Твой хват в полуактиве соответствует 7с, но щипок на уровне 6b...",
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

**Response:** `201 Created` → `{"id": 1}`

---

## 5. Профиль (расширение)

`GET /api/profile` — добавить при необходимости:
- `body_weight` — вес тела
- `strength_tier` — текущий ранг (Grasshopper, Stone Gecko, Mountain Lynx, Gravity Defier, Apex Predator)
- `unlocked_badges` — `["crab_claws", "hauler"]`

---

## 6. Таблица эндпоинтов

| Метод | Путь | Назначение |
|-------|------|------------|
| GET | `/api/climbing-logs/summary` | Сводка тренировок |
| GET | `/api/climbing-logs/statistics` | Графики, грейды |
| GET | `/api/climbing-logs/recommendations` | Рекомендации (в т.ч. asymmetry, pulling_weak) |
| POST | `/api/climbing-logs` | Сохранение сессии трасс |
| GET | `/api/climbing-logs/strength-tests` | История замеров силы |
| POST | `/api/climbing-logs/strength-tests` | Сохранение замера |
| GET | `/api/climbing-logs/strength-test-settings` | Настройки (вес тела) |
| PUT | `/api/climbing-logs/strength-test-settings` | Сохранение веса тела |
| GET | `/api/climbing-logs/strength-leaderboard` | Топ недели по силе |
| GET | `/api/climbing-logs/gamification` | XP, Streak, Recovery |
| POST | `/api/climbing-logs/training-plans` | Сохранение плана (опц.) |

---

## 7. Формулы (валидация на бэке)

- **Relative Strength (тяга):** `(body_weight + added_weight) / body_weight * 100`
- **1RM (Epley):** `total_weight * (1 + reps / 30)`
- **% от веса (пальцы/щипок):** `kg / body_weight * 100`
- **Асимметрия:** `|left - right| / max(left, right) * 100`

## 8. Безопасность

- Все эндпоинты: `Authorization: Bearer <token>`
- `body_weight_kg`: 30–200
- `reps`: 1–10
- `block_width_mm`: 40, 60, 80
