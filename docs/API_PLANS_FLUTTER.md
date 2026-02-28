# API планов тренировок — интеграция Flutter

Спецификация эндпоинтов и экранов для фронта.

---

## Эндпоинты

| Метод | URL | Назначение |
|-------|-----|------------|
| GET | `/api/climbing-logs/plan-templates?audience=` | Шаблоны и аудитории |
| POST | `/api/climbing-logs/plans` | Создание плана |
| GET | `/api/climbing-logs/plans/active` | Активный план |
| GET | `/api/climbing-logs/plans/{id}/day?date=` | План на день |
| GET | `/api/climbing-logs/plans/{id}/calendar?month=` | Календарь |
| POST | `/api/climbing-logs/plans/{id}/complete` | Отметить выполнение |
| DELETE | `/api/climbing-logs/plans/{id}/complete` | Убрать отметку |

---

## Реализация во Flutter

| Компонент | Файл |
|-----------|------|
| Модели | `lib/models/PlanModels.dart` |
| API | `lib/services/TrainingPlanApiService.dart` |
| Выбор плана | `lib/Screens/PlanSelectionScreen.dart` |
| Обзор / сегодня | `lib/Screens/PlanOverviewScreen.dart` |
| Календарь | `lib/Screens/PlanCalendarScreen.dart` |
| Экран дня | `lib/Screens/PlanDayScreen.dart` |

---

## Персонализация

### При создании плана (onboarding)
- Дней в неделю (2–6)
- Есть фингерборд (да/нет)
- Стиль лазания (болдер / труд / оба)
- Опыт (месяцев)
- Травмы (локти, пальцы, плечи, запястья)

### Перед сессией (кнопка «Уточнить» в экране дня)
- Самочувствие 1–5
- Фокус: лазание / сила / восстановление
- Время: 30 / 45 / 60 / 90 мин

См. `docs/BACKEND_PLANS_PERSONALIZATION.md` для бэкенда.

---

## Бэкенд: что поддержать (ofp_weekdays, sfp_weekdays)

Flutter передаёт опциональные поля **`ofp_weekdays`** и **`sfp_weekdays`** в POST и PATCH планов при выборе «Указать вручную».

### Новые поля

| Поле | Тип | Когда передаётся | Описание |
|------|-----|------------------|----------|
| `ofp_weekdays` | int[] | Режим «Указать вручную» | Дни для ОФП. ISO 8601: 1=Пн … 7=Вс |
| `sfp_weekdays` | int[] | Режим «Указать вручную» | Дни для СФП |

### Логика

1. **Если поля не переданы** — режим «Автоматически»:
   - Размещать ОФП/СФП во все `scheduled_weekdays` (текущее поведение).
   - Бэк сам решает, какой день OFP, какой SFP (по шаблону, ofp_sfp_focus).

2. **Если `ofp_weekdays` и/или `sfp_weekdays` переданы** — режим «Указать вручную»:
   - Дни из `ofp_weekdays` → **только ОФП** (лазание + ОФП).
   - Дни из `sfp_weekdays` → **только СФП** (лазание + СФП).
   - Дни из `scheduled_weekdays`, не входящие ни в один список, — **climbing-only** (только лазание, без упражнений).
   - `ofp_weekdays` и `sfp_weekdays` не пересекаются (фронт это гарантирует).
- Пустые массивы `[]` допустимы: оба пустые = все дни climbing-only.
- При ручном режиме `ofp_sfp_focus` **не передаётся** — фокус скрыт в UI, не нужен.

### Пример

```json
{
  "template_key": "amateur",
  "days_per_week": 4,
  "scheduled_weekdays": [1, 3, 5, 6],
  "ofp_weekdays": [1, 5],
  "sfp_weekdays": [3]
}
```

- Пн (1), Пт (5) — лазание + ОФП.
- Ср (3) — лазание + СФП.
- Сб (6) — только лазание.

### Чеклист для бэкенда

- [ ] POST `/api/climbing-logs/plans` — принимать и сохранять `ofp_weekdays`, `sfp_weekdays`
- [ ] PATCH `/api/climbing-logs/plans/{id}` — принимать `ofp_weekdays`, `sfp_weekdays`
- [ ] Размещать ОФП строго в `ofp_weekdays`, СФП — в `sfp_weekdays`
- [ ] GET `/plans/{id}/calendar` — `session_type: ofp` | `sfp` | `climbing` по назначению дня
- [ ] GET `/plans/{id}/day` — для climbing-only дат: `session_type: climbing`, пустой список упражнений

---

## Навигация

- Вкладка **«План»** в ClimbingLogScreen (2-я вкладка после «Обзор»).
- При отсутствии активного плана — кнопка «Создать план».
- При наличии — карточка «Сегодня» и кнопка «Календарь».

---

## Авторизация

Все запросы с `Authorization: Bearer <token>` (как в текущем API).
