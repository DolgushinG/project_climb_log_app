# Сохранение AI-сгенерированных упражнений в БД

**Делает бэкенд** — при обработке `POST /api/climbing-logs/workout/generate` бэкенд сам сохраняет упражнения из ответа AI в каталог БД.

Цель: экономия токенов (при следующих генерациях можно брать упражнения из БД) и расширение базы упражнений.

---

## Логика (на бэкенде)

1. Запрос приходит на `POST /api/climbing-logs/workout/generate`
2. Вызывается AI, получаем тренировку с блоками упражнений
3. **Перед возвратом ответа клиенту** — сохраняем все упражнения из ответа в таблицу `exercises`:
   - **Upsert** по `exercise_id`: если есть — обновить (hint, dosage, name_ru), если нет — вставить
4. Возвращаем JSON клиенту как обычно

Клиент (Flutter) **ничего не меняет** — только получает ответ от workout/generate.

---

## Формат упражнений (из ответа AI)

Каждое упражнение в блоках содержит:

| Поле | Тип | Описание |
|------|-----|----------|
| exercise_id | string | Уникальный id, ключ для upsert |
| name | string | Название (EN) |
| name_ru | string? | Название (RU) |
| category | string | ofp, sfp, stretching, warmup, cooldown |
| training_goal | string? | max_strength, hypertrophy, endurance |
| load_type | string? | strength, endurance, mobility |
| fatigue_index | int | 0–5 |
| default_sets | int | Подходов |
| default_reps | int/string | Повторения или время |
| hold_seconds | int? | Секунды виса (если execution_type=hold) |
| default_rest_seconds | int | Отдых между подходами |
| execution_type | string | reps, hold, timed |
| progression_type | string? | linear, wave |
| comment | string? | Краткий комментарий |
| hint | string? | Подсказка по выполнению |
| dosage | string? | Дозировка (3×10, 3×30с) |

---

## Рекомендации для БД

- Таблица `exercises` с уникальным `exercise_id`
- Upsert: `ON CONFLICT (exercise_id) DO UPDATE SET ...`
- Поле `source` (опционально): `catalog` | `ai_generated`

---

## Результат

При следующем вызове `workout/generate` бэкенд может:
- искать подходящие упражнения в каталоге (включая AI-добавленные)
- вызывать AI только для недостающих или для полной персональной комбинации
