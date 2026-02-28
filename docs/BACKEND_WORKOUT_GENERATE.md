# API умного подбора тренировок (Smart Workout)

Синхронизация фронта с бэкендом. Режим «цифровой тренер»: учитывает фазу цикла, усталость, стиль лазания, объясняет решения.

## Как использовать умного тренера

1. Умный тренер **всегда включён** — приложение автоматически подставляет:
   - **user_profile** (bodyweight) — из последних замеров силы;
   - **performance_metrics** (dead_hang_seconds, max_pullups) — из замеров и поля «Подтягивания»;
   - **recent_climbing_data** (sessions_last_7_days, average_grade) — из climbing log;
   - **fatigue_data** — текущая недельная нагрузка.
3. Бэкенд возвращает персональный контекст: `coach_comment`, `load_distribution`, `progression_hint`.
4. После генерации открывается отдельный экран результата — комментарии тренера закреплены сверху, блоки скроллятся внизу (без потери видимости подсказок).

---

## Эндпоинты

### POST /api/climbing-logs/workout/generate

**Заголовки:** `Authorization: Bearer <token>` или `x-telegram-init-data`

**Базовый request:**
```json
{
  "user_level": 2,
  "goal": "max_strength",
  "injuries": ["elbow_pain"],
  "available_time_minutes": 75,
  "experience_months": 12,
  "min_pullups": 10
}
```

**Расширенный (цифровой тренер):** + `day_offset`, `user_profile`, `performance_metrics`, `recent_climbing_data`, `fatigue_data`, `current_phase`

| goal | Отображение |
|------|-------------|
| max_strength | Макс. сила |
| hypertrophy | Гипертрофия |
| endurance | Выносливость |

**Ответ — поля coach context (когда передан):**
- `coach_comment` — «От тренера» (цитата)
- `why_this_session` — обоснование
- `progression_hint` — подсказка по прогрессии
- `load_distribution` — finger, endurance, strength, mobility (%)

---

### GET /api/climbing-logs/weekly-fatigue

**Ответ:**
```json
{
  "weekly_fatigue_sum": 18,
  "max_recommended": 35,
  "warning": null
}
```

---

## Модели Flutter

- `GenerateWorkoutRequest` — базовые + опциональные (UserProfile, PerformanceMetrics, FatigueData и т.д.)
- `WorkoutGenerateResponse` — blocks, warnings, weeklyFatigueWarning + coachComment, loadDistribution, progressionHint, whyThisSession, intensityExplanation
- `WeeklyFatigueResponse` — weeklyFatigueSum, maxRecommended, warning
