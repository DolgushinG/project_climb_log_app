# API: Пропуски упражнений (exercise-skips)

Спецификация для бэкенда — фиксация пропущенных упражнений (не могу выполнить по причине травмы, отсутствия снаряда и т.п.).

> Бэкенд может использовать историю пропусков при генерации планов и рекомендаций — например, реже предлагать упражнение, которое пользователь часто пропускает с причиной `no_equipment`.

---

## 1. Назначение

- Пользователь может отметить упражнение как **пропущенное** без записи в exercise-completions
- Пропуск не считается выполненным, но закрывает упражнение для сессии (можно завершить тренировку)
- Причина пропуска опциональна — для аналитики и персонализации

---

## 2. Эндпоинты

### 2.1 Список пропусков

**`GET /api/climbing-logs/exercise-skips`**

Query:
- `date` (YYYY-MM-DD) — пропуски за дату
- `period_days` (int, опц.) — за последние N дней

**Response:**
```json
{
  "skips": [
    {
      "id": 1,
      "date": "2025-02-13",
      "exercise_id": "max_hangs_3_5_7",
      "exercise_name": "Max Hangs 3-5-7",
      "reason": "no_equipment"
    }
  ]
}
```

### 2.2 Записать пропуск

**`POST /api/climbing-logs/exercise-skips`**

**Request:**
```json
{
  "date": "2025-02-13",
  "exercise_id": "max_hangs_3_5_7",
  "reason": "no_equipment"
}
```

| Поле         | Тип    | Обязательное | Описание |
|--------------|--------|--------------|----------|
| `date`       | string | да           | YYYY-MM-DD |
| `exercise_id`| string | да           | Идентификатор упражнения |
| `reason`     | string | нет          | Причина: `injury`, `no_equipment`, `fatigue`, `other`, или пустая строка |

**Response:** `201 Created` → `{"id": 1}`

На одну дату и один `exercise_id` — один пропуск. Повторный POST с тем же `date` + `exercise_id` — upsert (обновить reason или вернуть существующий id).

### 2.3 Отменить пропуск

**`DELETE /api/climbing-logs/exercise-skips/:id`**

Снимает пропуск (пользователь передумал).

**Response:** `200` или `204`

---

## 3. Интеграция с генерацией планов

При выборе упражнений для дня/недели бэкенд может:

- `GET /api/climbing-logs/exercise-skips?period_days=90` — получить историю пропусков
- Учитывать частоту пропусков по `exercise_id` и `reason`:
  - `no_equipment` — предпочитать упражнения без специального снаряда или предлагать альтернативы
  - `injury` — избегать или реже предлагать упражнение
  - `fatigue` / `other` — учитывать опционально

---

## 4. Схема БД (рекомендация)

```sql
CREATE TABLE exercise_skips (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id),
  date DATE NOT NULL,
  exercise_id VARCHAR(64) NOT NULL,
  reason VARCHAR(32),
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, date, exercise_id)
);
```

---

## 5. Фронт (Flutter)

- **StrengthTestApiService**: `getExerciseSkips`, `saveExerciseSkip`, `deleteExerciseSkip`
- **ExerciseCompletionScreen**: состояние `_skipped`, кнопка «Пропустить» рядом с чекбоксом
- Сессия завершаема когда: `(doneCount + skippedCount) == totalCount`
