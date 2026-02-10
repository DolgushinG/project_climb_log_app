# API: что допускается для guest (без токена)

## Итого: что допускается для guest

Без заголовка `Authorization` guest может:

### Читать

- **Список и детали соревнований** — `/api/competitions` (в т.ч. поле `statistics`)
- **Статистику события** — `/api/event/{event_id}/statistics`
- **Участников** — `/api/participants`
- **Результаты** (фестиваль / французская система) — `/api/results/festival`, `/api/results/france`
- **Трассы** — `/api/routes`
- **Публичный профиль** — `/api/public-profile/{id}`

### Получить токен (вход / регистрация)

- `POST /api/auth/token` — email + пароль
- `POST /api/auth/code/request` + `POST /api/auth/code/verify` — код на email
- `POST /api/auth/webauthn/options` + `POST /api/auth/webauthn/login` — passkey
- `POST /api/register` — регистрация

**Всё остальное в API требует заголовка `Authorization: Bearer <token>`.**

---

Для гостевого режима в приложении: показывать список соревнований, детали, участников, результаты и публичные профили без запроса логина; при действиях «записаться», «ввести результат», «профиль» и т.п. — запрашивать вход.
