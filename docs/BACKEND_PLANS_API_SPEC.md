# API планов — что должен отдавать бэкенд

Спецификация для интеграции Flutter с бэкендом планов тренировок.

---

## 1. GET /api/climbing-logs/plan-templates

**Query:** `?audience=beginner` (опционально; если не передан — все шаблоны)

**Минимальный ответ 200:**

```json
{
  "audiences": [
    {
      "key": "beginner",
      "name_ru": "Новичок",
      "template_count": 2
    },
    {
      "key": "intermediate",
      "name_ru": "Любитель",
      "template_count": 3
    }
  ],
  "templates": [
    {
      "key": "ofp_sfp_2_1",
      "name_ru": "2 ОФП + 1 СФП",
      "description": "Базовый план для новичков",
      "ofp_per_week": 2,
      "sfp_per_week": 1
    }
  ],
  "min_duration_weeks": 2,
  "max_duration_weeks": 12,
  "default_duration_weeks": 2
}
```

**Опционально:**

| Поле | Тип | Описание |
|------|-----|----------|
| `general_recommendations` | string[] | Рекомендации перед созданием плана |
| `plan_guide` | object | Текст для блока «О плане» (см. ниже) |
| `available_minutes_options` | int[] | Варианты времени: [30, 45, 60, 90] для любителей/профи |

**plan_guide** (если есть):

```json
{
  "short_description": "План автоматически подбирает упражнения под ваши дни и уровень...",
  "how_it_works": {
    "title": "Как строится план",
    "sections": [
      {"title": "1. Выбираете дни и уровень", "text": "..."},
      {"title": "2. Алгоритм распределяет сессии", "text": "..."}
    ]
  },
  "what_we_consider": {
    "title": "Что учитывается",
    "items": [{"label": "Количество дней", "text": "..."}]
  },
  "what_you_get": {
    "title": "Что вы получаете",
    "items": [{"label": "Календарь", "text": "..."}]
  },
  "session_types": {
    "ofp": {"name": "ОФП", "description": "..."},
    "sfp": {"name": "СФП", "description": "..."},
    "climbing": {"name": "Лазание", "description": "..."},
    "rest": {"name": "Отдых", "description": "..."}
  }
}
```

**Важно:** Без `audiences` и `templates` фронт показывает «Шаблоны недоступны».

---

## 2. POST /api/climbing-logs/plans

**Тело:**

| Поле | Обязательно | Описание |
|------|-------------|----------|
| `template_key` | да | Ключ шаблона из plan-templates |
| `duration_weeks` | да | 2–12 |
| `start_date` | нет | YYYY-MM-DD |
| `days_per_week` | нет | Кол-во дней |
| `scheduled_weekdays` | нет | [1,3,5] — Пн, Ср, Пт |
| `ofp_weekdays` | нет | Дни для ОФП (при «Указать вручную») |
| `sfp_weekdays` | нет | Дни для СФП (при «Указать вручную») |
| `has_fingerboard` | нет | bool |
| `injuries` | нет | ["elbow_pain", ...] |
| `preferred_style` | нет | boulder | lead | both |
| `experience_months` | нет | int |
| `include_climbing_in_days` | нет | bool, по умолчанию true |
| `available_minutes` | нет | 30 | 45 | 60 | 90 (для любителей/профи; новичок всегда 30) |
| `ofp_sfp_focus` | нет | balanced \| sfp \| ofp — фокус ОФП/СФП. По умолчанию balanced. Не передаётся при `ofp_weekdays`/`sfp_weekdays` (ручной режим). |

**Ответ 200/201:** объект `plan` с ActivePlan (id, template_key, start_date, end_date, scheduled_weekdays, scheduled_weekdays_labels, include_climbing_in_days).

---

## 2.1. PATCH /api/climbing-logs/plans/{id} (обновление плана)

См. **[BACKEND_PLANS_UPDATE_SPEC.md](BACKEND_PLANS_UPDATE_SPEC.md)** — полная спецификация для «Обновить план» (продление, смена дней, времени и др.).

---

## 3. GET /api/climbing-logs/plans/active

**Ответ 200 при наличии плана:**

```json
{
  "plan": {
    "id": 1,
    "template_key": "ofp_sfp_2_1",
    "start_date": "2026-02-17",
    "end_date": "2026-04-13",
    "scheduled_weekdays": [1, 3, 5],
    "scheduled_weekdays_labels": ["Пн", "Ср", "Пт"],
    "include_climbing_in_days": true
  }
}
```

**Ответ 200 при отсутствии плана (пустое состояние):**

```json
{
  "plan": null
}
```

Опционально в обоих случаях — `plan_guide` (как в plan-templates) для экрана «О плане».

---

## 4. GET /api/climbing-logs/plans/{id}/day

**Query:** `?date=YYYY-MM-DD`  
**Опционально:** `feeling=1..5`, `focus=climbing|strength|recovery`, `available_minutes=30|45|60|90`

**Ответ 200:**

```json
{
  "date": "2026-02-17",
  "session_type": "ofp",
  "week_number": 1,
  "ofp_day_index": 1,
  "sfp_day_index": null,
  "session_estimated_minutes": 42,
  "stretching_estimated_minutes": 12,
  "exercises": [
    {
      "name": "Приседания",
      "exercise_id": "squat_1",
      "sets": 3,
      "reps": "12",
      "dosage": "3 подхода по 12 повторений",
      "comment": null,
      "hint": "Спина прямая...",
      "climbing_benefit": "Ноги — основа стабильности на стене",
      "estimated_minutes": 6
    }
  ],
  "stretching": [
    {
      "zone": "Ноги",
      "exercises": [
        {
          "name": "Бабочка",
          "exercise_id": "stretch_butterfly_1",
          "hint": "20–30 сек на сторону",
          "climbing_benefit": "Гибкость бёдер...",
          "estimated_minutes": 2
        }
      ]
    }
  ],
  "completed": false,
  "completed_at": null,
  "coach_recommendation": "...",
  "why_this_session": "...",
  "expects_climbing": true,
  "session_intensity_modifier": 1.0
}
```

**session_type:** `ofp` | `sfp` | `rest` | `climbing`

- `climbing` — день только лазания, `exercises` = []
- `rest` — день отдыха

**Оценки времени:** `session_estimated_minutes`, `stretching_estimated_minutes`, у каждого упражнения — `estimated_minutes`.

---

## 5. GET /api/climbing-logs/plans/{id}/calendar

**Query:** `?month=YYYY-MM`

**Ответ 200:**

```json
{
  "month": "2026-02",
  "plan": { ... },
  "days": [
    {
      "date": "2026-02-17",
      "day_of_week": 1,
      "in_plan_range": true,
      "week_number": 1,
      "session_type": "ofp",
      "ofp_day_index": 1,
      "sfp_day_index": null,
      "completed": false
    }
  ]
}
```

**session_type** в днях: `ofp` | `sfp` | `rest` | `climbing`

---

## 6. POST /api/climbing-logs/plans/{id}/complete

**Тело:**

```json
{
  "date": "2026-02-17",
  "session_type": "ofp",
  "ofp_day_index": 1
}
```

**session_type:** `ofp` | `sfp` | `climbing`

---

## 7. DELETE /api/climbing-logs/plans/{id}/complete

**Тело:**

```json
{
  "date": "2026-02-17",
  "session_type": "ofp"
}
```

---

## 8. Отметки упражнений (exercise-completions)

Для чекбоксов у упражнений ОФП/СФП и растяжки:

- `POST /api/climbing-logs/exercise-completions` — тело: `{ "date", "exercise_id", "sets_done": 1 }`
- `GET /api/climbing-logs/exercise-completions?date=YYYY-MM-DD` — список выполненных
- `DELETE /api/climbing-logs/exercise-completions/{id}` — снять отметку

---

## 9. GET /api/climbing-logs/plans/{id}/progress (опционально, рекомендуется)

**Ответ 200:** `{ "completed": 5, "total": 24 }` — один запрос вместо N calendar по месяцам.

См. подробную спецификацию в [BACKEND_PLANS_PROGRESS.md](BACKEND_PLANS_PROGRESS.md).

---

## Чеклист для бэка

- [ ] GET plan-templates возвращает `audiences` и `templates` (не пустые)
- [ ] GET plan-templates поддерживает `?audience=`
- [ ] POST plans принимает `available_minutes`
- [ ] GET plans/active возвращает plan или null + опционально plan_guide
- [ ] GET plan day возвращает `session_type: climbing`, `session_estimated_minutes`, `stretching_estimated_minutes`
- [ ] Упражнения: `climbing_benefit`, `estimated_minutes`
- [ ] Растяжка: объекты с `exercise_id`, `hint`, `climbing_benefit`, `estimated_minutes`
- [ ] POST/DELETE complete поддерживают `session_type: climbing`
- [ ] (рекомендуется) GET plans/{id}/progress — completed/total за один запрос
