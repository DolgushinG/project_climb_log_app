# Backend: Роль тренера

Спецификация API для режима тренера: управление учениками, назначение упражнений, просмотр их тренировок и выполнений.

---

## 1. Обзор

Пользователь может включить «Режим тренера» в профиле. В этом режиме он получает доступ к:

- управлению группой учеников (добавление/удаление);
- назначению упражнений ученикам;
- просмотру тренировок и выполненных упражнений учеников;
- созданию собственных упражнений (если не нашёл в каталоге).

**Важно:** собственные упражнения тренера видны только ему и его ученикам. При назначении — в быстром доступе сверху.

**Все эндпоинты `/api/trainer/*` требуют Bearer token и проверки:**
1. У текущего пользователя `trainer_mode_enabled = true`;
2. При доступе к данным ученика — `student_id` входит в группу тренера (`trainer_students`).

---

## 2. Профиль и роль

### 2.1 GET /api/profile

Расширить ответ полем:

| Поле | Тип | Описание |
|------|-----|----------|
| `trainer_mode_enabled` | boolean | Режим тренера включён. По умолчанию `false` при отсутствии поля. |

### 2.2 PUT /api/profile (или PATCH /api/profile/edit)

Принимать в теле:

| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| `trainer_mode_enabled` | boolean | нет | Включить/выключить режим тренера |

Пример:
```json
{
  "trainer_mode_enabled": true
}
```

При сохранении обновлять поле в таблице `users` (или эквивалент).

---

## 3. Ученики тренера

**Важно:** Тренер не может просматривать данные ученика, пока тот не подтвердит приглашение. Только принятые приглашения попадают в список учеников.

### 3.1 GET /api/trainer/students

Список **только подтверждённых** учеников (status = accepted). Ученики с pending-приглашениями не возвращаются — тренер не видит и не может зайти к ним до подтверждения.

**Response:** `200 OK`
```json
{
  "students": [
    {
      "id": 42,
      "firstname": "Иван",
      "lastname": "Петров",
      "email": "ivan@example.com",
      "avatar": "https://...",
      "created_at": "2025-03-15T10:00:00Z"
    }
  ]
}
```

### 3.2 POST /api/trainer/students (приглашение)

Отправить приглашение. Ученик **не** добавляется в группу сразу — создаётся запись со статусом `pending`.

**По email:**
```json
{
  "email": "student@example.com"
}
```

**По user_id** (если ученик уже в системе и известен тренеру — опционально):
```json
{
  "user_id": 42
}
```

**Логика:**
- Пользователь с email найден → создать `trainer_student_invitations` (или аналог) со статусом `pending`
- Пользователь не найден → `404` или отправить email-инвайт на регистрацию (на усмотрение бэкенда)

**Response:** `201 Created`
```json
{
  "status": "pending",
  "email": "student@example.com",
  "message": "Приглашение отправлено. Ученик появится в списке после принятия."
}
```

Ученик **не** возвращается в `GET /api/trainer/students` до подтверждения.

**Ошибки:**
- `403` — не включён режим тренера;
- `403` с `error: "trainer_students_limit_reached"` — достигнут лимит учеников (3 для free, см. [BACKEND_TRAINER_STUDENTS_LIMIT.md](./BACKEND_TRAINER_STUDENTS_LIMIT.md));
- `404` — пользователь не найден (если нет логики email-инвайта);
- `422` — уже в группе или приглашение уже отправлено.

### 3.3 GET /api/trainer/invitations (опц.)

Список отправленных приглашений со статусом `pending` — чтобы тренер видел «Ожидают подтверждения».

**Response:** `200 OK`
```json
{
  "invitations": [
    {
      "id": 1,
      "email": "student@example.com",
      "status": "pending",
      "created_at": "2025-03-15T10:00:00Z"
    }
  ]
}
```

### 3.3.1 DELETE /api/trainer/invitations/{id} (отзыв приглашения)

Тренер отменяет своё отправленное pending-приглашение. Слот освобождается, тренер может пригласить другого.

| Критерий | Описание |
|----------|----------|
| Права | Только тренер, владелец приглашения |
| Условие | Приглашение в статусе `pending` |
| Результат | Удаление или `status = revoked` |

**Response:** `200` или `204`

**Ошибки:**
- `403` — не тренер или не владелец;
- `404` — приглашение не найдено;
- `422` — приглашение уже принято или отозвано.

См. [BACKEND_TRAINER_STUDENTS_LIMIT.md](./BACKEND_TRAINER_STUDENTS_LIMIT.md) для деталей лимита.

### 3.4 Принятие приглашения (для ученика)

**POST /api/trainer/invitations/{id}/accept** (или `/api/profile/trainer-invitations/{id}/accept`)

Вызывается учеником. Переводит статус в `accepted`, создаёт запись в `trainer_students`. После этого ученик появляется в `GET /api/trainer/students`.

**Обязательные проверки перед добавлением в trainer_students:**
1. Приглашение существует;
2. Приглашение в статусе `pending` (не отозвано, не принято ранее);
3. Текущий пользователь — приглашённый (student_id или email совпадает);
4. У тренера есть свободный слот (подписка активна или `students + pending < 3`).

**Ошибки:**
- `404` — приглашение не найдено или уже отозвано/принято;
- `403` с `error: "trainer_students_limit_reached"` — тренер достиг лимита учеников.

**DELETE /api/trainer/invitations/{id}/reject** — отклонить (вызывается учеником).

### 3.5 GET /api/profile/trainer-invitations (для ученика)

Список входящих приглашений от тренеров — чтобы ученик мог принять или отклонить.

**Response:** `200 OK`
```json
{
  "invitations": [
    {
      "id": 1,
      "trainer_id": 42,
      "trainer_name": "Иван Петров",
      "status": "pending"
    }
  ]
}
```

### 3.6 GET /api/profile/trainer-assignments (для ученика)

Список назначений **для текущего пользователя** (ученика). Ученик видит только свои задания от тренеров.

| Query | Описание |
|-------|----------|
| date | string, опц. YYYY-MM-DD — задания на дату |
| period_days | int, опц. За последние N дней (если date не указан) |

**Response:** `200 OK` — тот же формат, что и `GET /api/trainer/assignments`, но `student_id` = текущий пользователь.

**Важно для упражнений из trainer_exercises:** бэкенд **обязательно** должен вернуть в каждом элементе доп. поля (JOIN с trainer_exercises), иначе ученик не увидит подсказки «Как выполнять» и «Польза для скалолазания»:

| Поле | Тип | Описание |
|------|-----|----------|
| how_to_perform | string | **Обязательно** для trainer_exercises. Как выполнять упражнение. |
| climbing_benefits | string | **Обязательно** для trainer_exercises. Польза для скалолазания. |

### 3.7 DELETE /api/trainer/students/{user_id}

Удалить ученика из группы тренера.

**Response:** `200` или `204`

**Ошибки:**
- `403` — не тренер или ученик не в группе;
- `404` — ученик не найден.

---

## 4. Назначения упражнений

### 4.1 GET /api/trainer/assignments

Список назначений. Обязательный query: `student_id`.

| Query | Описание |
|-------|----------|
| `student_id` | int, обязательный. ID ученика |
| `date` | string, опц. YYYY-MM-DD — фильтр по дате |
| `period_days` | int, опц. За последние N дней |

**Response:** `200 OK`
```json
{
  "assignments": [
    {
      "id": 1,
      "exercise_id": "pull_ups",
      "exercise_name": "Подтягивания",
      "exercise_name_ru": "Подтягивания",
      "date": "2025-03-16",
      "sets": 3,
      "reps": "10",
      "hold_seconds": null,
      "rest_seconds": 90,
      "status": "completed",
      "created_at": "2025-03-15T12:00:00Z"
    },
    {
      "id": 2,
      "exercise_id": "trainer_42_1",
      "exercise_name": "Мой вис",
      "exercise_name_ru": "Мой вис",
      "date": "2025-03-16",
      "sets": 3,
      "reps": "6",
      "hold_seconds": null,
      "rest_seconds": 90,
      "status": "pending",
      "how_to_perform": "Вис на турнике, кисти параллельно...",
      "climbing_benefits": "Укрепляет предплечья и хват",
      "created_at": "2025-03-15T12:00:00Z"
    }
  ]
}
```

**status:** `pending` | `completed` | `skipped` — вычисляется для каждого назначения по данным **ученика** (student_id) за `date` назначения:

1. Есть запись в **exercise-completions** (user_id = student_id, date, exercise_id) → `"completed"`
2. Иначе есть запись в **exercise-skips** (user_id = student_id, date, exercise_id) → `"skipped"`
3. Иначе → `"pending"`

Оба источника (completions и skips) обязательны. Без exercise-skips пропущенные упражнения отображаются тренеру как «ожидают».

Для упражнений из `trainer_exercises` (exercise_id типа `trainer_{id}_{n}`) обязательно включать `how_to_perform` и `climbing_benefits` (JOIN с trainer_exercises), иначе ученик не увидит подсказки при выполнении.

**Важно для status в assignments:** при вычислении `status` (pending/completed/skipped) для каждого назначения бэкенд проверяет exercise-completions и exercise-skips за дату назначения. Проверка должна учитывать **все** exercise_id, включая `trainer_{id}_{n}` — иначе задание от тренера всегда будет `pending` даже после выполнения.

**Важно:** API `POST /api/climbing-logs/exercise-completions` и `GET /api/climbing-logs/exercise-completions` должны принимать и возвращать `exercise_id` для упражнений тренера (формат `trainer_{id}_{n}`) так же, как для каталога. Не фильтровать и не отклонять trainer ID — иначе выполненное задание от тренера не отобразится как выполненное.

### 4.2 POST /api/trainer/assignments

Создать назначение.

**Request:**
```json
{
  "student_id": 42,
  "exercise_id": "pull_ups",
  "date": "2025-03-16",
  "sets": 3,
  "reps": "10",
  "hold_seconds": null,
  "rest_seconds": 90
}
```

| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| student_id | int | да | ID ученика |
| exercise_id | string | да | ID из каталога упражнений |
| date | string | да | YYYY-MM-DD |
| sets | int | да | Количество подходов |
| reps | string | да | Повторения («10», «max», «30») |
| hold_seconds | int \| null | нет | Секунды удержания (растяжка) |
| rest_seconds | int | нет (default 90) | Отдых между подходами |

**Response:** `201 Created`
```json
{
  "id": 1,
  "student_id": 42,
  "exercise_id": "pull_ups",
  "date": "2025-03-16",
  "sets": 3,
  "reps": "10"
}
```

### 4.3 DELETE /api/trainer/assignments/{id}

Удалить назначение.

**Response:** `200` или `204`

---

## 5. Просмотр данных ученика

### 5.1 GET /api/trainer/students/{id}/climbing-history

История сессий лазания ученика. Формат как у `GET /api/climbing-logs/history`, но для указанного ученика.

| Query | Описание |
|-------|----------|
| `period_days` | int, опц. За последние N дней (default 90) |
| `limit` | int, опц. Лимит записей |

**Response:** `200 OK` — массив сессий в формате climbing-logs/history.

### 5.2 GET /api/trainer/students/{id}/exercise-completions

Выполненные упражнения ученика.

| Query | Описание |
|-------|----------|
| `date` | string, опц. YYYY-MM-DD — за конкретную дату |
| `period_days` | int, опц. За последние N дней (default 30) |

**Response:** `200 OK`
```json
{
  "completions": [
    {
      "id": 1,
      "date": "2025-03-15",
      "exercise_id": "pull_ups",
      "exercise_name": "Подтягивания",
      "sets_done": 3,
      "weight_kg": 25.5,
      "notes": ""
    }
  ]
}
```

### 5.3 GET /api/trainer/students/{id}/plans

Активный план ученика (если нужен в карточке тренера).

**Response:** `200 OK` — объект плана в формате `GET /api/climbing-logs/plans/active`, или `{}` если плана нет.

---

## 6. Собственные упражнения тренера

Каждый тренер может создавать свои упражнения, если не нашёл подходящее в общем каталоге. Упражнения видны **только тренеру и его ученикам**. При назначении упражнений — свои упражнения показываются в быстром доступе сверху.

### 6.1 POST /api/trainer/exercises/generate-ai

Сгенерировать описание «как выполнять» и «польза для скалолазания» по названию упражнения через AI.

**Request:**
```json
{
  "name": "Подтягивания с паузой"
}
```

**Response:** `200 OK`
```json
{
  "how_to_perform": "Техника выполнения упражнения...",
  "climbing_benefits": "Польза для скалолазов..."
}
```

| Поле ответа | Тип | Описание |
|-------------|-----|----------|
| how_to_perform | string | Как выполнять упражнение |
| climbing_benefits | string | Польза для скалолазания |

### 6.2 POST /api/trainer/exercises

Создать упражнение. Видно только тренеру и его ученикам.

**Request:**
```json
{
  "name": "Подтягивания с паузой",
  "name_ru": "Подтягивания с паузой",
  "category": "sfp",
  "how_to_perform": "Вис на турнике, подтягивание с паузой в верхней точке...",
  "climbing_benefits": "Укрепляет мышцы спины и предплечий, полезно для лазания на скалах",
  "default_sets": 3,
  "default_reps": "6",
  "default_rest": "180s",
  "hold_seconds": null
}
```

| Поле | Тип | Обязательное | Описание |
|------|-----|--------------|----------|
| name | string | да | Название (одно поле, русское) |
| name_ru | string | нет | Дублирует name |
| category | string | да | ofp \| sfp \| stretching |
| how_to_perform | string | да | Как выполнять упражнение |
| climbing_benefits | string | да | Польза для скалолазания |
| description | string | нет | (устаревшее, для совместимости) |
| default_sets | int | нет (default 3) | Подходы |
| default_reps | string | нет (default "6") | Повторения |
| default_rest | string | нет (default "90s") | Отдых (например "180s") |
| hold_seconds | int | нет | Секунды удержания (растяжка) |

**Response:** `201 Created`
```json
{
  "id": "trainer_42_1",
  "name": "Подтягивания с паузой",
  "name_ru": "Подтягивания с паузой",
  "category": "sfp",
  "how_to_perform": "...",
  "climbing_benefits": "...",
  "default_sets": 3,
  "default_reps": "6",
  "default_rest": "180s",
  "hold_seconds": null
}
```

`id` — уникальный идентификатор для назначений (в `exercise_id`). Рекомендуется: префикс `trainer_{trainer_id}_` + счётчик или slug.

### 6.3 GET /api/trainer/exercises

Список своих упражнений тренера.

**Response:** `200 OK`
```json
{
  "exercises": [
    {
      "id": "trainer_42_1",
      "name": "Подтягивания с паузой",
      "name_ru": "Подтягивания с паузой",
      "category": "sfp",
      "how_to_perform": "...",
      "climbing_benefits": "...",
      "default_sets": 3,
      "default_reps": "6",
      "default_rest": "180s",
      "hold_seconds": null
    }
  ]
}
```

### 6.4 PUT /api/trainer/exercises/{id}

Редактирование (id — строковый идентификатор из 6.2/6.3).

### 6.5 DELETE /api/trainer/exercises/{id}

Удаление. Если есть активные назначения — вернуть `422` с сообщением.

---

## 7. Схема данных (рекомендации)

```sql
-- users: добавить колонку
ALTER TABLE users ADD COLUMN trainer_mode_enabled BOOLEAN DEFAULT FALSE;

-- Связь тренер — ученики
-- Подтверждённые связки тренер — ученик
CREATE TABLE trainer_students (
  id SERIAL PRIMARY KEY,
  trainer_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  student_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(trainer_id, student_id)
);

-- Приглашения (pending) — до подтверждения учеником
CREATE TABLE trainer_student_invitations (
  id SERIAL PRIMARY KEY,
  trainer_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  student_id INT REFERENCES users(id) ON DELETE SET NULL,
  email VARCHAR(255),
  status VARCHAR(20) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Назначения упражнений
CREATE TABLE trainer_assignments (
  id SERIAL PRIMARY KEY,
  trainer_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  student_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  exercise_id VARCHAR(100) NOT NULL,
  assigned_date DATE NOT NULL,
  sets INT NOT NULL DEFAULT 3,
  reps VARCHAR(20) NOT NULL DEFAULT '10',
  hold_seconds INT,
  rest_seconds INT DEFAULT 90,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_trainer_assignments_student_date ON trainer_assignments(student_id, assigned_date);

-- Собственные упражнения тренера (видны только тренеру и ученикам)
CREATE TABLE trainer_exercises (
  id SERIAL PRIMARY KEY,
  trainer_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  exercise_id VARCHAR(100) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  name_ru VARCHAR(255),
  category VARCHAR(50) NOT NULL,
  description TEXT,
  how_to_perform TEXT NOT NULL,
  climbing_benefits TEXT NOT NULL,
  default_sets INT DEFAULT 3,
  default_reps VARCHAR(20) DEFAULT '6',
  default_rest VARCHAR(20) DEFAULT '90s',
  hold_seconds INT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_trainer_exercises_trainer ON trainer_exercises(trainer_id);
```

---

## 8. Чеклист для бэкенда

- [ ] Добавить `trainer_mode_enabled` в GET/PUT /api/profile
- [ ] GET /api/trainer/students — только подтверждённые ученики
- [ ] POST /api/trainer/students — отправить приглашение (pending)
- [ ] Логика принятия: ученик подтверждает → появляется в trainer_students
- [ ] GET /api/trainer/invitations — список отправленных pending-приглашений (опц.)
- [ ] DELETE /api/trainer/invitations/{id} — тренер отзывает приглашение (только pending)
- [ ] GET /api/profile/trainer-invitations — входящие приглашения для ученика
- [ ] GET /api/profile/trainer-assignments — мои задания от тренера (для ученика)
- [ ] POST /api/trainer/invitations/{id}/accept — ученик принимает
- [ ] DELETE /api/trainer/invitations/{id}/reject — ученик отклоняет
- [ ] DELETE /api/trainer/students/{user_id} — удалить ученика
- [ ] GET /api/trainer/assignments?student_id= — список назначений
- [ ] POST /api/trainer/assignments — создать назначение
- [ ] DELETE /api/trainer/assignments/{id} — удалить назначение
- [ ] GET /api/trainer/students/{id}/climbing-history — история лазания ученика
- [ ] GET /api/trainer/students/{id}/exercise-completions — выполнения ученика
- [ ] GET /api/trainer/students/{id}/plans — активный план ученика (опц.)
- [ ] Авторизация: проверка trainer_mode_enabled и принадлежности student к группе
- [ ] POST /api/trainer/exercises/generate-ai — сгенерировать «как выполнять» и «польза» по названию (AI)
- [ ] GET /api/trainer/exercises — список своих упражнений
- [ ] POST /api/trainer/exercises — создать упражнение (how_to_perform, climbing_benefits — обязательные)
- [ ] PUT /api/trainer/exercises/{id} — редактировать
- [ ] DELETE /api/trainer/exercises/{id} — удалить (422 если есть назначения)
- [ ] При назначении: exercise_id может быть из каталога или из trainer_exercises
