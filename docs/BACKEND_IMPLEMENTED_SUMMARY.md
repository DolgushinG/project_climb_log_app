# Сводка реализованных изменений на бэкенде

Документ фиксирует состояние бэкенда после внедрения изменений из роадмапа.

---

## 1. План тренировок (календарь и день)

### `GET /api/climbing-logs/plans/{id}/calendar`
- `days` — только даты в диапазоне `[start_date, end_date]`
- `completed: true` — только для дат с POST /complete (ofp/sfp) или записью в strength-tests (measurement)
- В объекте `plan` добавлено поле `include_climbing_in_days`

### `GET /api/climbing-logs/plans/{id}/day`
- Дни с `session_type: measurement` возвращают данные (exercises: [], stretching, coach_comment)
- Метка «День замеров силы» для `session_type: measurement`
- В упражнениях: `dosage`, `hint`, `exercise_id`

### `POST /api/climbing-logs/plans`
- `include_climbing_in_days` принимается и сохраняется

### `GET /api/climbing-logs/plans/active`
- `include_climbing_in_days` возвращается

### `GET /api/climbing-logs/history`
- Параметр `?date=YYYY-MM-DD` поддерживается

---

## 2. Дни замеров

- `session_type: 'measurement'` поддерживается в calendar и day (amateur_plans_schedule)
- `POST /api/climbing-logs/strength-tests` — принимает `plan_id`

---

## 3. Слабые звенья

- `weak_links` — `[{ key, label_ru, hint }]`
- `targets_weak_link` — в упражнениях

---

## 4. Замеры силы

- `POST /api/climbing-logs/strength-tests` — возвращает `{"id": N}`
- `GET /api/climbing-logs/strength-tests` — в каждом элементе есть `id`
- `DELETE /api/climbing-logs/strength-tests/:id` — удаление по ID

---

## 5. RuStore Push

- `POST /api/climbing-logs/device-push-token`
- Тело: `{ "token": "...", "platform": "rustore"|"fcm"|"ios", "device_id": "..." }`
- Таблица `device_push_tokens`, модель `DevicePushToken`

**Миграция:** `docker exec app php artisan migrate`
