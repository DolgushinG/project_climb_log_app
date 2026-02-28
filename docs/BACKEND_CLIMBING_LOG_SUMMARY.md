# Backend API для экрана «Обзор» (Summary / Dashboard) тренировок

Экран «Обзор» во вкладке «Тренировки» использует следующие эндпоинты.

---

## Реализованные эндпоинты

### 1. `GET /api/climbing-logs/summary`

Сводка для дашборда без загрузки полной истории.

**Query:**
- `period` (опционально): `week` | `month` | `all` — период для агрегации (по умолчанию `all`).

**Response:**
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

**Польза:** один запрос вместо progress + history, меньше данных по сети.

---

### 2. `GET /api/climbing-logs/statistics`

Статистика по периодам для графиков.

**Query:**
- `group_by`: `day` | `week` | `month`
- `period_days`: количество дней (например, 30, 90)

**Response:**
```json
{
  "labels": ["01.01", "08.01", "15.01", "22.01", "29.01"],
  "sessions": [2, 4, 3, 5, 2],
  "routes": [18, 35, 28, 42, 19],
  "grades_breakdown": [
    {"grade": "6B", "count": 45},
    {"grade": "6B+", "count": 32},
    {"grade": "7A", "count": 8}
  ]
}
```

**Польза:** готовые агрегаты для графиков, можно менять группировку на бэке.

---

### 3. `GET /api/climbing-logs/recommendations`

Предложения на основе данных о тренировках.

**Response:**
```json
{
  "recommendations": [
    {
      "type": "streak",
      "text": "Отличная серия! 5 дней подряд",
      "priority": 1
    },
    {
      "type": "next_grade",
      "text": "Следующий грейд для покорения: 7A+",
      "priority": 2
    },
    {
      "type": "frequency",
      "text": "Добавьте ещё 1–2 тренировки в неделю для стабильного прогресса",
      "priority": 3
    }
  ]
}
```

**Польза:** централизованная логика рекомендаций, можно менять правила без обновления приложения.

---

## Зависимости

- Все эндпоинты требуют Bearer token.
