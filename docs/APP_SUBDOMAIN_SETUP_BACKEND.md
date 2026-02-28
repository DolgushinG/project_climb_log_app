# Инструкция: настройка app.climbing-events.ru (Flutter Web)

Документ для бэкенд-команды: что нужно настроить на сервере и в Laravel, чтобы веб-приложение (Flutter Web) работало на поддомене `app.climbing-events.ru`.

**Роль бэкенда:** только пути (Nginx) и поддержка домена (DNS, SSL, CORS). Сборка и деплой Flutter — на стороне мобильной/фронтенд команды.

---

## 1. DNS

Добавить A-запись или CNAME:

```
app.climbing-events.ru  →  <IP вашего сервера>
```

Если используется wildcard, `*.climbing-events.ru` уже может покрывать `app`. Тогда шаг можно пропустить.

---

## 2. SSL-сертификат

Нужен сертификат для `app.climbing-events.ru`.

**Вариант A:** Wildcard `*.climbing-events.ru` — уже покрывает `app.climbing-events.ru`.

**Вариант B:** Отдельный certbot для поддомена:
```bash
certbot certonly --nginx -d app.climbing-events.ru
```

---

## 3. Nginx — раздача Flutter Web

Фронтенд Flutter — статические файлы (HTML, JS, CSS). Их нужно раздавать с поддомена.

**3.1. Папка для файлов**

Создать каталог на сервере, куда будет деплоиться сборка Flutter Web, например:

```
/var/www/app.climbing-events.ru/
```

Содержимое — результат `flutter build web` (файлы из папки `build/web/`):
- `index.html`
- `main.dart.js`
- `flutter.js`
- `flutter_bootstrap.js`
- `flutter_service_worker.js`
- папки `assets/`, `canvaskit/`, `icons/`

**3.2. Конфиг Nginx**

Создать отдельный vhost или добавить server block, например:

```nginx
server {
    listen 80;
    server_name app.climbing-events.ru;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name app.climbing-events.ru;

    ssl_certificate     /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;

    root /var/www/app.climbing-events.ru;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Entry points — НЕ кэшировать (иначе пользователи не получают обновления). См. docs/WEB_CACHE_UPDATE.md
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
    location = /manifest.json { add_header Cache-Control "no-cache, no-store, must-revalidate"; }
    location = /flutter_service_worker.js { add_header Cache-Control "no-cache, no-store, must-revalidate"; }
    location = /flutter_bootstrap.js { add_header Cache-Control "no-cache, no-store, must-revalidate"; }
    location = /flutter.js { add_header Cache-Control "no-cache, no-store, must-revalidate"; }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

**3.3. Перезагрузка Nginx**

```bash
nginx -t
systemctl reload nginx
```

---

## 3.4. Редирект Flutter-ассетов с climbing-events.ru

Если PWA или пользователи запрашивают `flutter_service_worker.js`, `flutter_bootstrap.js` и т.п. с **основного домена** `climbing-events.ru`, приходит 404 — эти файлы есть только на `app.climbing-events.ru`.

**Решение:** в `server`-блоке для `climbing-events.ru` добавить редиректы на `app.climbing-events.ru`:

```nginx
# Внутри server { ... } для climbing-events.ru (НЕ app)
# Редирект Flutter-ассетов на app-поддомен (PWA и кэш могут стучаться с основного домена)
location ~ ^/(flutter_service_worker\.js|flutter_bootstrap\.js|flutter\.js|main\.dart\.js|manifest\.json)$ {
    return 301 https://app.climbing-events.ru$request_uri;
}
location ~ ^/(assets|canvaskit|icons)/ {
    return 301 https://app.climbing-events.ru$request_uri;
}
```

После правок: `nginx -t && systemctl reload nginx`.

**Важно:** Service Worker требует same-origin — страница и worker должны быть с одного домена. Редирект убирает 404 в логах, но для работы PWA пользователь должен открывать приложение на **app.climbing-events.ru**. В `index.html` Flutter добавлен редирект с climbing-events.ru → app.

---

## 4. Laravel CORS (API)

Flutter Web с `app.climbing-events.ru` делает запросы к `https://climbing-events.ru/api/...`. Laravel должен разрешать origin `https://app.climbing-events.ru`.

**4.1. config/cors.php**

Добавить origin в массив `allowed_origins`:

```php
'allowed_origins' => [
    'https://climbing-events.ru',
    'https://www.climbing-events.ru',
    'https://climbing-events.ru.tuna.am',  // dev
    'https://app.climbing-events.ru',      // ← добавить
    'http://localhost:*',                  // локальная разработка
],
```

**4.2. Если CORS обрабатывается middleware**

Проверить, что middleware или пакеты (например `fruitcake/laravel-cors`) не блокируют запросы с `app.climbing-events.ru`.

---

## 4a. CORS для изображений (Nginx)

Flutter Web загружает постеры и аватарки с `https://climbing-events.ru/storage/images/...`. Эти файлы обычно отдаются **Nginx напрямую**, а не Laravel, поэтому CORS из `config/cors.php` на них не распространяется.

Без заголовка `Access-Control-Allow-Origin` браузер блокирует отображение картинок (особенно в CanvasKit-рендерере Flutter Web).

**Решение:** в Nginx-конфиге **основного домена** `climbing-events.ru` (не app) добавить location для `/storage/`:

```nginx
# Внутри server { ... } для climbing-events.ru
location /storage/ {
    # ... существующие настройки для storage ...
    add_header Access-Control-Allow-Origin "https://app.climbing-events.ru" always;
}
```

Если `location /storage/` уже есть — просто добавьте строку `add_header` в этот блок.

**Для нескольких origin** (prod + stage):

```nginx
location /storage/ {
    set $cors_origin "";
    if ($http_origin ~* "^https://(app\.climbing-events\.ru|app\.stage-dev\.climbing-events\.ru)$") {
        set $cors_origin $http_origin;
    }
    add_header Access-Control-Allow-Origin $cors_origin always;
}
```

После изменений: `nginx -t && systemctl reload nginx` (или перезапуск контейнера nginx).

---

## 5. Раздел «Приложения» в Laravel

В блоке, где отображаются ссылки на приложения (iOS, Android), добавить пункт для веб-версии (временно как «версия для iOS»):

- **Заголовок:** «Версия для iOS» или «Веб-приложение»
- **Описание:** «Пока приложения нет в App Store — используйте веб-версию. Откройте в Safari и добавьте на главный экран.»
- **Ссылка:** `https://app.climbing-events.ru`
- **Кнопка:** «Открыть приложение» / «Перейти в приложение»

Конкретное место в шаблонах и тексты — на усмотрение команды.

---

## 6. Кто деплоит Flutter Web

Сборку (`flutter build web`) и заливку файлов в папку делает мобильная/фронтенд команда. Бэкенд создаёт папку `/var/www/app.climbing-events.ru/` (пустую или с placeholder), настраивает Nginx — дальше туда деплоится статика.

---

## 7. Проверка

1. `https://app.climbing-events.ru` — открывается Flutter-приложение.
2. Логин через Laravel API — работает (CORS не блокирует).
3. API-запросы с `app.climbing-events.ru` к `climbing-events.ru/api/...` проходят.
4. Постеры и аватарки (`/storage/images/...`) отображаются на страницах соревнований и профилей.

---

## 8. Краткий чеклист для бэкенда

**Бэкенду нужно только:**

- [ ] **Пути:** Nginx — server block для `app.climbing-events.ru`, root → папка со статикой
- [ ] **Домен:** DNS + SSL для `app.climbing-events.ru`
- [ ] **CORS API:** добавить `https://app.climbing-events.ru` в Laravel `allowed_origins`
- [ ] **CORS изображения:** в Nginx для `climbing-events.ru` добавить `add_header Access-Control-Allow-Origin` в `location /storage/`
- [ ] **UI:** ссылка в разделе «Приложения» на `https://app.climbing-events.ru`

Сборку Flutter Web деплоит мобильная команда в указанную папку. Бэкенд только обеспечивает раздачу и доступ по домену.
