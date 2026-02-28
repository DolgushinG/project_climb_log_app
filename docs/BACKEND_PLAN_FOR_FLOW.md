# Бэкенд: требования для корректной работы плана и «Продолжить тренировку»

Чтобы работали «Продолжить тренировку по плану» и «Осталось X упражнений», бэкенд должен возвращать данные в описанном формате.

---

## 1. GET /api/climbing-logs/plans/active

**Ответ:**
```json
{
  "id": 12,
  "template_key": "novice_zero",
  "start_date": "2026-02-14",
  "end_date": "2026-02-27",
  "scheduled_weekdays": [1, 3, 5],
  "scheduled_weekdays_labels": ["Пн", "Ср", "Пт"]
}
```

- `scheduled_weekdays` — 1=Пн … 7=Вс (ISO 8601)
- `scheduled_weekdays_labels` — подписи для отображения

---

## 2. GET /api/climbing-logs/plans/{id}/day?date=YYYY-MM-DD

**Ответ для дня с упражнениями:**
```json
{
  "date": "2026-02-14",
  "session_type": "ofp",
  "week_number": 1,
  "ofp_day_index": 1,
  "sfp_day_index": null,
  "exercises": [
    {
      "exercise_id": "plan_0_a1b2c3d4",
      "name": "Подтягивания",
      "sets": 3,
      "reps": "8",
      "dosage": "3 подхода по 8 повторений",
      "comment": null,
      "hint": "Базовое упражнение для спины. Держитесь за перекладину хватом на ширине плеч..."
    },
    {
      "exercise_id": "plan_1_e5f6g7h8",
      "name": "Вис на полусогнутых",
      "sets": 3,
      "reps": "10с",
      "dosage": "3 подхода по 10 сек",
      "comment": null,
      "hint": "Укрепите хват, держите корпус напряжённым..."
    }
  ],
  "stretching": [
    {
      "zone": "Плечи",
      "exercises": ["Маятник", "Растяжка над головой"]
    }
  ],
  "completed": false,
  "completed_at": null,
  "coach_recommendation": "Сегодня фокус на силу и стабилизацию корпуса.",
  "estimated_minutes": 45,
  "load_level": "Средняя",
  "session_focus": "Неделя 1"
}
```

Обязательные поля:
- `session_type`: `ofp` | `sfp` | `rest`
- `exercises` — массив `{ name, sets, reps, comment?, exercise_id?, dosage?, hint? }`
- `completed` — отметка завершения сессии

Опциональные поля упражнения:
- `exercise_id` — идентификатор для сопоставления с exercise-completions (если есть — фронт использует его)
- `dosage` — готовый текст дозировки («3 подхода по 12 повторений»); при наличии приоритет над sets+reps (см. [PLAN_EXERCISE_HINTS_AND_DOSAGE.md](PLAN_EXERCISE_HINTS_AND_DOSAGE.md))
- `hint` — подсказка «Как выполнять»; отображается кнопкой «Как выполнять» и в модальном окне при нажатии

Опционально (блок «От тренера» на экране плана):
- `coach_recommendation` — рекомендация на день
- `estimated_minutes` — ориентировочное время тренировки
- `load_level` — нагрузка (Лёгкая / Средняя / Высокая / Отдых)
- `session_focus` — фокус сессии (например «Неделя 1»)

---

## 3. GET /api/climbing-logs/exercise-completions?date=YYYY-MM-DD (для «Осталось X упражнений»)

Фронт считает остаток упражнений так:

1. Получает план дня через `GET /plans/{id}/day?date=…`
2. Генерирует `exercise_id` для каждого упражнения: `plan_{index}_{hash(name)}`
3. Берёт список exercise-completions за дату (API замеров/силы)
4. Оставшиеся = общее число упражнений − число совпавших `exercise_id`

Для совпадения `exercise_id` между планом и exercise-completions фронт использует схему `plan_{index}_{hash(name)}`. Бэкенд может:

- Либо возвращать `exercise_id` в каждом элементе `exercises` — тогда фронт будет использовать его.
- Либо оставить генерацию на фронте (как сейчас).

**Если бэкенд добавит `exercise_id` в упражнение плана:**

```json
{
  "exercises": [
    {
      "exercise_id": "ex_123",
      "name": "Подтягивания",
      "sets": 3,
      "reps": "8"
    }
  ]
}
```

Фронт нужно будет обновить, чтобы брать `exercise_id` из ответа. Пока используется генерация на клиенте.

---

## 4. POST /api/climbing-logs/plans/{id}/complete

**Тело:**
```json
{
  "date": "2026-02-14",
  "session_type": "ofp",
  "ofp_day_index": 1
}
```

- `ofp_day_index` — при `session_type: ofp`, если бэкенд его использует.

---

## 5. DELETE /api/climbing-logs/plans/active (очистка для тестирования)

**Запрос:**
```
DELETE /api/climbing-logs/plans/active
Authorization: Bearer {token}
```

**Ответ:** 200 или 204 (без тела).

Бэкенд удаляет/деактивирует активный план текущего пользователя. После этого GET /plans/active вернёт пусто/404.

---

## 6. DELETE /api/climbing-logs/exercise-completions (полная очистка для тестирования)

**Запрос:**
```
DELETE /api/climbing-logs/exercise-completions
Authorization: Bearer {token}
```

**Ответ (200):**
```json
{
  "deleted": 42
}
```

Бэкенд удаляет **все** exercise-completions текущего пользователя.  
Используется для «как новый пользователь».

---

## 7. DELETE /api/climbing-logs/exercise-completions?date=YYYY-MM-DD (очистка за дату)

**Запрос:**
```
DELETE /api/climbing-logs/exercise-completions?date=2026-02-14
Authorization: Bearer {token}
```

**Ответ (200):**
```json
{
  "deleted": 6
}
```

Бэкенд удаляет все exercise-completions текущего пользователя за указанную дату.  
Если DELETE без параметра не реализован, фронт использует этот fallback.

---

## 8. Согласованность календарь ↔ день

Календарь (GET /plans/{id}/calendar) возвращает дни с `session_type`: `ofp`, `sfp`, `rest`.  
**GET /plans/{id}/day?date=…** для этих дат **должен** возвращать данные. Если день показан в календаре как ОФП или СФП, но GET /day возвращает null/404, пользователь увидит «Данные не загружены».

Рекомендация: для всех дат, входящих в диапазон плана и перечисленных в `days` календаря, GET /day должен возвращать валидный ответ с `exercises` (для ofp/sfp) или `session_type: rest` (для дней отдыха).

---

## 9. Краткий чеклист

| Эндпоинт | Что важно |
|----------|-----------|
| GET /plans/active | `scheduled_weekdays`, `scheduled_weekdays_labels` |
| DELETE /plans/active | Удаление плана (для теста) |
| GET /plans/{id}/day | `exercises`, `completed`, `session_type` |
| GET /exercise-completions?date= | Возвращать `exercise_id` в каждом completion |
| POST /exercise-completions | Принимать и сохранять `exercise_id` |
| POST /plans/{id}/complete | Корректная обработка после выполнения сессии |
| DELETE /exercise-completions | Полная очистка всех отметок (для теста) |
| DELETE /exercise-completions?date= | Очистка за дату (fallback) |
| GET /plans/{id}/calendar ↔ /day | Календарь и день должны быть согласованы: для каждой даты в days — GET /day возвращает данные |