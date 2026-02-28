# Деплой Flutter Web через GitHub Actions

Workflow автоматически собирает и выкладывает Flutter Web на сервер при push в `master` или `main`.

---

## 1. Настройка GitHub Secrets

В репозитории: **Settings → Secrets and variables → Actions** → **New repository secret**.

Создайте секреты:

| Секрет | Описание | Пример |
|--------|----------|--------|
| `DEPLOY_SSH_KEY` | Приватный SSH-ключ для доступа к серверу | Весь вывод `cat ~/.ssh/id_rsa` |
| `DEPLOY_HOST` | IP или домен сервера | `123.45.67.89` или `server.climbing-events.ru` |
| `DEPLOY_USER` | SSH-пользователь на сервере | `deploy` или `root` |
| `DEPLOY_PORT` | SSH-порт (обязателен, если порт не стандартный 22) | `2222` |
| `DEPLOY_PATH` | (опционально) Путь на сервере | По умолчанию `/var/www/app.climbing-events.ru` |

---

## 2. Генерация SSH-ключа для деплоя

На своей машине (или на сервере, где будет выполняться GitHub Actions):

```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f deploy_key -N ""
```

- `deploy_key` — приватный ключ → сохранить в `DEPLOY_SSH_KEY`
- `deploy_key.pub` — публичный ключ → добавить на сервер в `~/.ssh/authorized_keys` пользователя `DEPLOY_USER`

Либо использовать существующий ключ, если он уже добавлен на сервер.

---

## 3. Настройка сервера

1. Создать пользователя (если нужен отдельный деплой-пользователь):
   ```bash
   sudo useradd -m deploy
   sudo mkdir -p /var/www/app.climbing-events.ru
   sudo chown deploy:deploy /var/www/app.climbing-events.ru
   ```

2. Добавить публичный ключ в `~/.ssh/authorized_keys` для пользователя `DEPLOY_USER`.

3. Убедиться, что папка `/var/www/app.climbing-events.ru` существует и доступна для записи.

---

## 4. Триггеры workflow

- **Авто:** push в ветки `master` или `main`
- **Вручную:** Actions → Deploy Flutter Web → Run workflow

---

## 5. Файл workflow

`.github/workflows/deploy-web.yml`

При необходимости измените:
- `flutter-version` — под вашу версию Flutter
- `branches` — ветки для автодеплоя
- `DEPLOY_PATH` — если путь на сервере другой
