# Обновление веб-билда: принудительная загрузка новых версий

Чтобы браузеры и PWA получали новую версию без ручной очистки кэша, нужны изменения в **сборке**, **манифесте** и **конфигурации сервера (Nginx)**.

---

## 1. Что уже сделано в проекте

### `scripts/web_version_bump.sh`
Перед `flutter build web` скрипт:
- Добавляет `?v=BUILD` к `flutter_bootstrap.js` в `index.html`
- Добавляет `?v=BUILD` в `start_url` в `manifest.json` (PWA при открытии получает «новый» URL)

В GitHub Actions это вызывается автоматически перед билдом (`.github/workflows/deploy-web.yml`).

---

## 2. Обязательно: правки Nginx

**Проблема:** сейчас JS/CSS кэшируются на 1 год (`expires 1y`). В эту категорию попадают `flutter_service_worker.js` и `flutter_bootstrap.js`. Service worker **должен** каждый раз запрашиваться заново, иначе браузер не видит обновления.

### Обновлённый конфиг Nginx

Добавьте `location` для entry-point файлов **до** блока с `\.(js|css|...)`:

```nginx
server {
    listen 443 ssl http2;
    server_name app.climbing-events.ru;

    root /var/www/app.climbing-events.ru;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Не кэшировать entry-point файлы — без этого новая версия не подтягивается
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    location = /manifest.json {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    location = /flutter_service_worker.js {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    location = /flutter_bootstrap.js {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    location = /flutter.js {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Остальные ассеты можно кэшировать надолго (hash в имени)
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

**Важно:** блоки `location = /...` должны идти **перед** общим `location ~* \.(js|...)`, иначе для точных путей сработает общее правило.

### После правок

```bash
nginx -t && systemctl reload nginx
```

---

## 3. Если используется CDN (Cloudflare и т.п.)

- После деплоя **очищайте кэш CDN** вручную (Purge Cache).
- Либо настройте Page Rule: для `app.climbing-events.ru/index.html`, `manifest.json`, `flutter_service_worker.js`, `flutter_bootstrap.js` — bypass cache.
- Либо включайте Development Mode на время деплоя.

---

## 4. Увеличение build number при релизе

При каждом релизе увеличивайте build number в `pubspec.yaml`:

```yaml
version: 1.0.0+4   # было +3, стало +4
```

Тогда `web_version_bump.sh` подставит новый `?v=4` в entry points, и пользователи получат свежую версию при следующем открытии страницы.

---

## 5. Краткий чеклист

- [ ] Nginx: `Cache-Control: no-cache` для `index.html`, `manifest.json`, `flutter_service_worker.js`, `flutter_bootstrap.js`, `flutter.js`
- [ ] CDN: Purge Cache после деплоя или bypass cache для entry points
- [ ] При каждом релизе — `version: X.Y.Z+BUILD` в pubspec и деплой через Actions (bump запускается автоматически)
