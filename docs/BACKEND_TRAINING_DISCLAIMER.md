# API подтверждения дисклеймера плана и тренировок

Требования для сохранения факта ознакомления пользователя с информационным характером плана и рекомендаций. Используется для снижения юридических рисков.

---

## GET /api/climbing-logs/training-disclaimer-acknowledged

**Метод:** `GET`  
**Авторизация:** Bearer token

Проверка: уже подтвердил ли пользователь дисклеймер. Вызывается при переустановке приложения — локальные данные потеряны, бэкенд сохраняет факт.

**Ответ 200:**

```json
{
  "acknowledged": true,
  "acknowledged_at": "2026-02-16T12:00:00.000Z"
}
```

| Поле | Тип | Описание |
|------|-----|----------|
| `acknowledged` | bool | true если пользователь подтвердил |
| `acknowledged_at` | string | ISO 8601, когда подтвердил |

Если пользователь ещё не подтверждал — бэкенд возвращает `acknowledged: false` или 404.  
Flutter считает подтверждённым, если `acknowledged == true` **или** `acknowledged_at != null`.

---

## Контекст

Перед созданием плана или генерацией тренировки пользователь видит дисклеймер:

> План и рекомендации носят исключительно информационный характер и не являются медицинской или профессиональной консультацией. При травмах, болях или сомнениях проконсультируйтесь с врачом или тренером. Вы самостоятельно несёте ответственность за нагрузку и технику выполнения. Лазание и силовые тренировки несут риск травм.
>
> ☐ Ознакомлен(а), принимаю

После установки галочки и нажатия «Создать план» / «Сгенерировать» Flutter-приложение:
1. Сохраняет факт локально (SharedPreferences)
2. Отправляет POST-запрос на бэкенд

---

## POST /api/climbing-logs/training-disclaimer-acknowledged

**Метод:** `POST`  
**Авторизация:** Bearer token

**Тело запроса:**

```json
{
  "acknowledged": true,
  "acknowledged_at": "2026-02-16T12:00:00.000Z"
}
```

| Поле | Тип | Описание |
|------|-----|----------|
| `acknowledged` | bool | Всегда `true` |
| `acknowledged_at` | string | ISO 8601 UTC, момент подтверждения |

**Ответ:**
- `200`, `201` или `204` — успех
- `401` — не авторизован

**Ошибки:**
- Бэкенд может игнорировать запрос — Flutter при ошибке сети/500 всё равно продолжает работу (локально сохранено).

---

## Поведение бэкенда

1. **GET** — по user_id из токена вернуть `acknowledged: true` и `acknowledged_at`, если запись есть. Иначе — `acknowledged: false` или 404.
2. **POST** — сохранить в профиле пользователя или отдельной таблице `training_disclaimer_acknowledged_at` (datetime).
3. Не требуется идемпотентность — повторные POST можно перезаписывать.
4. Фронт вызывает GET при заходе на экран (если локально нет флага). POST — один раз при первом подтверждении.

**Пример таблицы (если отдельная):**

```sql
-- user_id, acknowledged_at
INSERT INTO training_disclaimer_acknowledgments (user_id, acknowledged_at)
VALUES (:user_id, :acknowledged_at)
ON CONFLICT (user_id) DO UPDATE SET acknowledged_at = EXCLUDED.acknowledged_at;
```

**Или в профиле:**
```sql
UPDATE users SET training_disclaimer_acknowledged_at = :ts WHERE id = :user_id;
```

---

## Flutter: что отправляется

- Эндпоинт: `POST $DOMAIN/api/climbing-logs/training-disclaimer-acknowledged`
- Headers: `Authorization: Bearer <token>`, `Content-Type: application/json`
- При ошибке сети или 4xx/5xx — приложение продолжает (локальный флаг уже установлен)
