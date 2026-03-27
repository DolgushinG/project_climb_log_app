# Веб-приложение на `app.*` и работа на iOS

В проекте уже собран **Flutter Web** (PWA): `web/index.html`, редирект с `climbing-events.ru` → `app.climbing-events.ru`, passkeys, манифест. Ниже — как выложить на свой **app.domain** и что нужно для **iPhone (Safari)** и опционально для **открытия ссылок в нативном приложении**.

## 1. Сборка

```bash
./scripts/web_version_bump.sh
flutter build web --release --no-web-resources-cdn
```

Артефакт: `build/web/` — его раздаётте как статику с **HTTPS**.

`--no-web-resources-cdn` — шрифты/ресурсы из сборки, без CDN (как у вас в скриптах).

## 2. API и домен

В **release** `lib/main.dart` задаёт `DOMAIN = https://climbing-events.ru` (прод API). Само веб-приложение может жить на **другом хосте**, например `https://app.climbing-events.ru`: запросы идут на **API-домен** с заголовком `Authorization: Bearer …` — это **нормально**, если на бэкенде для API настроен **CORS**:

- разрешить origin веб-приложения: `https://app.climbing-events.ru` (или ваш `app.domain`);
- методы: `GET, POST, PUT, PATCH, DELETE, OPTIONS` по необходимости;
- заголовки: `Authorization`, `Content-Type`, `Accept`.

Без CORS Safari на iOS будет блокировать ответы API.

### T‑Банк и `client_origin`

При `POST .../payment/tbank/init` Flutter Web передаёт **`client_origin`** = `Uri.base.origin` (например `https://app.climbing-events.ru`). Бэкенд должен строить **Success/Fail URL** для T‑Банка на этом origin, иначе после оплаты откроется другой сайт (часто с формой входа), пока в вкладке PWA уже «оплачено». Подробнее: `docs/API_TBANK_GROUP_PAYMENT_INIT.md`.

Оплата T‑Банка на **web** — **новая вкладка** (не iframe): после оплаты банк редиректит на страницы с сессией сайта, в iframe это превращалось в «логин внутри приложения». Параллельно на вкладке PWA идёт **polling** статуса; показывается SnackBar «вернитесь в это окно». Редиректы success/fail всё равно лучше строить с **`client_origin`** (см. выше).

## 3. Деплой на `app.domain`

1. DNS: `A`/`AAAA` или `CNAME` на ваш CDN/сервер.
2. TLS: сертификат (Let’s Encrypt и т.д.).
3. Корень сайта = содержимое `build/web/`.
4. Кэш: HTML / `flutter_bootstrap.js` / `manifest.json` — **короткий TTL или no-cache** (см. `docs/WEB_CACHE_UPDATE.md` при наличии).

### Редирект с корня маркетингового домена

В `web/index.html` уже есть скрипт: с `climbing-events.ru` редирект на `app.climbing-events.ru`. Для другого имени замените хосты в скрипте или настройте редирект на **nginx/CDN**.

## 4. iOS Safari — «как приложение»

Уже в `index.html`:

- `apple-mobile-web-app-capable`, `apple-touch-icon`;
- `manifest.json` с `display: standalone`.

Пользователь: **Поделиться → На экран «Домой»** — откроется без адресной строки (ограничения iOS по PWA — норма).

## 5. Universal Links (ссылки `https://app.domain/...` открывают **нативное** приложение)

Нужно одновременно:

### A. Файл на сайте веб-приложения

Шаблон: `web/.well-known/apple-app-site-association` (в репозитории). После деплоя должен открываться по:

`https://<ваш-app-хост>/.well-known/apple-app-site-association`

- Без расширения `.json`.
- Ответ **HTTPS**, статус **200**, тип **`application/json`** (часто достаточно `Content-Type: application/json`).

Подставьте **`TEAMID`** (Apple Developer → Membership) и проверьте **`appID`**: `TEAMID.com.climbingevents.app` (bundle id из Xcode).

### B. Xcode (iOS)

1. Target **Runner** → **Signing & Capabilities** → **+ Capability** → **Associated Domains**.
2. Добавить: `applinks:app.climbing-events.ru` (или ваш хост **без** `https://`).

Можно завести `Runner.entitlements` с ключом `com.apple.developer.associated-domains` и подключить его в Build Settings → **Code Signing Entitlements** (как в примере ниже — см. `ios/Runner/Runner.entitlements.example`).

После публикации Apple подтянет AASA (иногда задержка до суток; для отладки см. документацию Apple «Universal Links»).

## 6. Что проверить на iPhone

- Логин, список событий, оплата (если открывается во внешнем окне — уже учтено в коде для web).
- Passkeys / вход — нужен `passkeys_bundle.js` и HTTPS на том же origin.
- Премиум-редиректы: в коде для web используются `Uri.base.origin` + страницы `web/premium/success`, `web/premium/fail` — их тоже нужно раздавать с `app.domain`.

## 7. E2E / другой API

Сборка с `--dart-define=USE_DEV_API=true` или `API_URL=...` — для тестов; прод на `app.domain` обычно без этого.

---

**Итог:** веб-часть в репозитории уже есть; остаётся **задеплоить** `build/web` на **app.domain**, включить **CORS** на API для этого origin, при необходимости поправить **редирект** в `index.html`, для нативных ссылок — **AASA** + **Associated Domains** в iOS.
