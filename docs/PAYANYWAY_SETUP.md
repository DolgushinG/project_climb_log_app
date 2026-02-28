# Настройка PayAnyWay (MONETA.RU) в приложении

## URL: в чём разница

| URL | Где настраивается | Назначение |
|-----|-------------------|------------|
| **Pay URL (webhook)** | Личный кабинет MONETA.ru | Куда PayAnyWay **отправляет POST** с отчётом об оплате. Бэкенд по нему активирует подписку. Не передаётся в запросе оплаты. |
| **MNT_SUCCESS_URL** | В `payment_urls.ini` | Куда **перенаправить** после оплаты. Используем `climbingevents://premium/success` — deep link |
| **MNT_FAIL_URL** | То же | `climbingevents://premium/fail` — при ошибке/отмене |

**Текущий флоу (deep link):**
1. PayAnyWay перенаправляет на `climbingevents://premium/success` (или `/fail`)
2. WebView перехватывает этот URL в `shouldOverrideUrlLoading`
3. PayAnyWayActivity закрывается → пользователь возвращается в приложение
4. Схема `climbingevents` зарегистрирована в AndroidManifest — при открытии извне откроется приложение

**Важно:** в кабинете MONETA.ru должен быть включён флаг **«Можно переопределять настройки в URL»**.

### Flutter Web: success_url и fail_url

- **climbing-events.ru** — основной сайт
- **app.climbing-events.ru** — веб-приложение

Flutter Web **всегда явно передаёт** `success_url` и `fail_url` на домен приложения (`Uri.base.origin`), например:
```json
{
  "amount": 199,
  "email": "user@example.com",
  "success_url": "https://app.climbing-events.ru/premium/success",
  "fail_url": "https://app.climbing-events.ru/premium/fail"
}
```

Так редирект идёт в приложение, а не на основной домен. Иначе пользователь окажется на climbing-events.ru и может потерять контекст (другая сессия/cookies).

**Рекомендация для Laravel:** добавить в `.env` fallback-переменные на случай, когда клиент не передаёт URL:
```env
PAYANYWAY_SUCCESS_URL=https://app.climbing-events.ru/premium/success
PAYANYWAY_FAIL_URL=https://app.climbing-events.ru/premium/fail
```
Использовать их, если `success_url`/`fail_url` не пришли в запросе.

---

## Что уже сделано

Приложение интегрировано с PayAnyWay Android SDK по [документации](https://payanyway.ru/info/p/ru/public/merchants/SDKandroid.pdf):

- **MonetaSdk** — формирует URL платёжной формы MONETA.Assistant
- **MonetaSdkConfig** — загрузка настроек из INI
- **PayAnyWayActivity** — экран с WebView для оплаты
- **Method Channel** — вызов из Flutter на Android

## Настройка для работы платежей

### 1. Регистрация в PayAnyWay/MONETA.ru

1. Зарегистрируйтесь на [moneta.ru](https://www.moneta.ru) или [payanyway.ru](https://payanyway.ru)
2. Создайте расширенный счёт для приёма платежей
3. Получите:
   - `monetasdk_account_id` — номер счёта
   - `monetasdk_account_code` — код проверки (если включена подпись запросов)

### 2. Конфигурация в приложении

Отредактируйте `android/app/src/main/assets/android_basic_settings.ini`:

```ini
# "1" = demo-сервер (для тестов), "0" = продакшен
monetasdk_demo_mode = "1"

# "1" = тестовый режим, "0" = боевые платежи
monetasdk_test_mode = "1"

# Ваши данные из личного кабинета MONETA.ru
monetasdk_account_id = "ВАШ_НОМЕР_СЧЁТА"
monetasdk_account_code = "ВАШ_КОД"   # или "" если проверка выключена
```

### 3. Платёжная система

По умолчанию используется **все способы оплаты** (`payment_system=all`): карты, СБП, SberPay, электронные кошельки (если включены в ЛК MONETA.ru).  
Для ограничения только картами — передать `payment_system=plastic` в Intent.  
Настройки `plastic` в `android_payment_systems.ini` — если нужен режим «только карты».

**СБП и другие способы:** включите их в [moneta.ru](https://www.moneta.ru) → Рабочий кабинет → Способы оплаты.

### 4. Переход в продакшен

Перед релизом:

1. `monetasdk_demo_mode = "0"`
2. `monetasdk_test_mode = "0"`
3. Настройте callback URL в личном кабинете MONETA.ru для уведомлений об оплате

## Ссылки

- [SDK Android PDF](https://payanyway.ru/info/p/ru/public/merchants/SDKandroid.pdf)
- [MONETA.Assistant](https://www.moneta.ru/doc/MONETA.Assistant.ru.pdf)
- [Merchant API](https://www.moneta.ru/doc/MONETA.MerchantAPI.v2.ru.pdf)
