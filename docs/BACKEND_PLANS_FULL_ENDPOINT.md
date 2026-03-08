# GET /api/climbing-logs/plans/active/full — объединённый endpoint (Batch API)

**Категория:** optimization  
**Приоритет:** high  
**Цель:** Сократить число запросов PlanOverviewScreen с 6 до 1, снизить latency с 2–3 с до 0.8–1 с.

---

## Запрос

```
GET /api/climbing-logs/plans/active/full?date=YYYY-MM-DD
```

**Query-параметры:**

| Параметр | Обязателен | Описание |
|----------|------------|----------|
| `date`   | да         | YYYY-MM-DD — дата для «Сегодня» (plan_day, completions, skips, climbing_history) |
| `light`  | нет        | 1 — rule-based day без AI (быстрее) |

**Авторизация:** Bearer token.

**Примечание:** Используется `active` — endpoint возвращает данные активного плана текущего пользователя. Если активного плана нет — `plan: null`, остальные поля пусты/дефолтны.

---

## Ответ 200

JSON-объект со всеми данными для PlanOverviewScreen:

```json
{
  "plan": { ... },
  "plan_guide": { ... },
  "today": { ... },
  "progress": { "completed": 5, "total": 24 },
  "completions": [ { "id": 1, "date": "2026-03-09", "exercise_id": "squat_1", "sets_done": 1 } ],
  "skips": [ { "id": 1, "date": "2026-03-09", "exercise_id": "pull_1", "reason": null } ],
  "climbing_history": [ { "id": 10, "date": "2026-03-09", "gym_name": "...", "routes": [...] } ]
}
```

### Поля

| Поле | Тип | Описание |
|------|-----|----------|
| `plan` | object \| null | ActivePlan (как в GET plans/active). null — план не найден или не принадлежит пользователю |
| `plan_guide` | object | PlanGuide (как в GET plan-templates / plans/active) |
| `today` | object \| null | PlanDayResponse для `date`. null — дата вне диапазона плана или день не найден |
| `progress` | object | `{ "completed": N, "total": M }` — как GET plans/{id}/progress |
| `completions` | array | Exercise completions за `date` (формат как GET exercise-completions?date=) |
| `skips` | array | Exercise skips за `date` (формат как GET exercise-skips?date=) |
| `climbing_history` | array | История лазания (формат как GET climbing-logs/history). Нужна только для проверки «есть ли лазание за date» — можно отдавать полный список или только сессии за последние 7 дней |

### Форматы вложенных объектов

- **plan** — см. GET plans/active, объект `plan`
- **plan_guide** — см. BACKEND_PLANS_API_SPEC, `plan_guide`
- **today** — см. GET plans/{id}/day, полный ответ
- **progress** — см. GET plans/{id}/progress
- **completions** — массив `{ id, date, exercise_id, sets_done?, weight_kg? }`
- **skips** — массив `{ id, date, exercise_id, reason? }`
- **climbing_history** — массив `{ id, date, gym_name, gym_id?, routes: [{ grade, count }] }`

---

## Laravel (пример реализации)

```php
// routes/api.php
Route::get('climbing-logs/plans/active/full', [TrainingPlanController::class, 'full'])
    ->middleware('auth:sanctum');

// TrainingPlanController
public function full(Request $request): JsonResponse
{
    $date = $request->query('date');
    if (!$date || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
        return response()->json(['error' => 'date required (YYYY-MM-DD)'], 400);
    }

    $plan = TrainingPlan::where('user_id', $request->user()->id)
        ->where('is_active', true)
        ->with(['workouts', 'completions', 'skips'])
        ->first();

    if (!$plan) {
        return response()->json([
            'plan' => null,
            'plan_guide' => $this->getPlanGuide(),
            'today' => null,
            'progress' => ['completed' => 0, 'total' => 0],
            'completions' => [],
            'skips' => [],
            'climbing_history' => [],
        ], 200);
    }

    $cacheKey = "plan:full:{$plan->id}:{$date}";
    $result = Cache::tags(["plan:{$plan->id}"])->remember($cacheKey, 60, function () use ($plan, $date) {
        $today = $this->planDayService->getDay($plan, $date);
        $progress = $this->planProgressService->getProgress($plan);
        $completions = $this->exerciseCompletionService->getForDate($date);
        $skips = $this->exerciseSkipService->getForDate($date);
        $history = $this->climbingHistoryService->getForUser($plan->user_id);

        return [
            'plan' => $plan->toActivePlanFormat(),
            'plan_guide' => $this->getPlanGuide(),
            'today' => $today,
            'progress' => $progress,
            'completions' => $completions,
            'skips' => $skips,
            'climbing_history' => $history,
        ];
    });

    return response()->json($result);
}
```

**Кэш:** `Cache::tags(['plan:' . $id])->remember(60)` — TTL 60 сек. Инвалидировать при complete/uncomplete, patch plan.

---

## Ответ 404

Если endpoint не реализован — 404. Flutter при 404 использует fallback на старые endpoints (getActivePlan + getPlanDay + ...).

---

## Чеклист для бэка

- [ ] GET plans/active/full?date= реализован
- [ ] Возвращает plan, plan_guide, today, progress, completions, skips, climbing_history
- [ ] Eager loading для снижения N+1
- [ ] Кэш 60 сек по plan:id и date
- [ ] Проверка user_id — только свой план
