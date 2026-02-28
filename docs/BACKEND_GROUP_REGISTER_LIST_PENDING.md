# Backend: лист ожидания и категории в групповой регистрации

## available-sets (для новых участников по дате рождения)

`GET /api/event/{id}/available-sets?dob=YYYY-MM-DD`

После ввода даты рождения вызывается запрос. В ответе — сеты с `list_pending`:

```json
{
  "availableSets": [
    {"id": 1, "number_set": 1, "free": 5, "time": "10:00", "list_pending": false},
    {"id": 2, "number_set": 2, "free": 0, "time": "14:00", "list_pending": true}
  ]
}
```

- `list_pending: true` — мест нет, участник будет добавлен в лист ожидания
- `list_pending: false` — есть свободные места

## available-category (фильтр по сету)

`GET /api/event/{id}/available-category?dob=YYYY-MM-DD&number_set=N`

При выборе сета запрашиваются категории, подходящие для этого сета. Если параметр `number_set` не поддерживается, фронт использует категории только по `dob`.

## group-register / sets (для ранее заявленных участников)

Если `GET /api/event/{id}/group-register` возвращает сеты в `sets[]`, каждый элемент может содержать:

| Поле | Тип | Описание |
|------|-----|----------|
| `list_pending` | `boolean` | `true` — мест нет, лист ожидания |

Фронт показывает в выпадающем списке: `(лист ожидания)` вместо `(N мест)` и отправляет `list_pending: 'true'` в `related_users`.

## Отправка при регистрации

- **Новые участники** (`participants[]`): `list_pending: 'true'` или `'false'` — в зависимости от выбранного сета
- **Ранее заявленные** (`related_users[]`): `list_pending: 'true'` или `'false'`

### related_users с list_pending: "true"

Для участников в листе ожидания обязательно передавать `dob` в формате `YYYY-MM-DD` (из поля `birthday` в ответе group-register):

```json
{
  "user_id": 2537,
  "sets": 1,
  "category": "1 группа (2011-2010)",
  "list_pending": "true",
  "dob": "2010-02-14"
}
```

Если у related user нет даты рождения в профиле (поле `birthday` пустое или отсутствует), участника нельзя добавить в лист ожидания — на фронте показывается сообщение «Укажите дату рождения участника».

---

## Лист ожидания для каждого участника (add/remove)

### Поля в related_users (ответ group-register)

| Поле | Тип | Описание |
|------|-----|----------|
| `is_in_list_pending` | `boolean` | `true` — участник уже в листе ожидания |
| `list_pending_number_sets` | `int[]` | Номера сетов (например `[1, 2]`), иначе `null` |

### UI

- `is_in_list_pending: true` → «Уже в листе ожидания (Сет 1, 2)» + кнопки «Изменить» / «Удалить»
- `is_in_list_pending: false` и есть сеты с `list_pending: true` → кнопка «Добавить в лист ожидания»

### POST /api/event/{id}/add-to-list-pending

Добавление/изменение участника в листе ожидания.

**Тело запроса:**
```json
{
  "user_id": 2537,
  "number_sets": [1, 2],
  "birthday": "2010-02-14",
  "category": "1 группа (2011-2010)",
  "sport_category": "3 юн"
}
```

- `user_id` — ID related_user
- `number_sets` — массив номеров сетов (только сеты с `list_pending: true`)
- `birthday` — обязательно (YYYY-MM-DD)
- `category`, `sport_category` — по требованиям события

### POST /api/event/{id}/remove-from-list-pending

Удаление участника из листа ожидания.

**Тело запроса:**
```json
{
  "user_id": 2537
}
```

- `user_id` — ID related_user (обязательно для групповой регистрации)
