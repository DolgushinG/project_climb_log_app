# GET /api/climbing-logs/plans/{id}/progress — прогресс плана (один запрос)

Спека для бэкенда. Позволяет получить completed/total за **один запрос** вместо N запросов calendar по месяцам.

---

## Проблема

Сейчас Flutter для отображения «Прогресс плана» (X из Y дней) вызывает `GET /plans/{id}/calendar?month=YYYY-MM` **для каждого месяца** диапазона плана:

- План 2 месяца → 2 запроса
- План 12 месяцев → 12 запросов

Это создаёт лишнюю нагрузку и замедляет первую загрузку.

---

## Решение: GET /api/climbing-logs/plans/{id}/progress

**Метод:** `GET`  
**Авторизация:** Bearer token (как для других endpoints планов)

**Query:** без параметров (всё берётся из плана)

**Ответ 200:**

```json
{
  "completed": 5,
  "total": 24
}
```

| Поле    | Тип | Описание |
|---------|-----|----------|
| `completed` | int | Количество выполненных тренировочных дней (ofp, sfp, climbing) на сегодня или раньше |
| `total`     | int | Общее количество тренировочных дней в плане (start_date .. end_date) |

**Учтёт в `total`:** дни с `session_type` ∈ {`ofp`, `sfp`, `climbing`}.  
**Учтёт в `completed`:** те же дни, где есть отметка POST /complete и дата ≤ сегодня.

Дни отдыха (`rest`) не считаются.

---

## Логика

1. Взять план по id, проверить доступ пользователя.
2. Пройти все даты в [start_date, end_date].
3. Для каждой даты определить session_type (ofp/sfp/climbing/rest) по расписанию (scheduled_weekdays и т.д.).
4. `total` = количество дней с session_type ∈ {ofp, sfp, climbing}.
5. `completed` = количество из них, где дата ≤ сегодня и есть запись в таблице complete (POST /plans/{id}/complete).

---

## Ошибки

- `404` — план не найден или не принадлежит пользователю
- `401` — не авторизован

---

## Flutter

После реализации endpoint'а Flutter сначала вызывает `GET /plans/{id}/progress`.  
Если вернулся 200 — использует `completed` и `total` сразу.  
Если 404 или ошибка — fallback на старую схему (календарь по месяцам) для обратной совместимости.

---

## Чеклист для бэка

- [ ] GET /api/climbing-logs/plans/{id}/progress реализован
- [ ] Возвращает `completed` и `total` в формате JSON
- [ ] `total` — только ofp/sfp/climbing, без rest
- [ ] `completed` — только даты ≤ сегодня с отметкой complete
