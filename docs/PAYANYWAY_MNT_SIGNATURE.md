# Ошибка «Неправильная подпись формы оплаты» (MNT_SIGNATURE)

## Кто генерирует подпись

**MNT_SIGNATURE** формируется на **бэкенде** при создании `payment_url` для PayAnyWay (assistant.widget). Flutter отправляет запрос на `/api/premium/create-payment` и получает готовый URL — подпись в нём уже вычислена бэкендом.

Ошибка «Неправильная подпись формы оплаты» означает, что PayAnyWay отклоняет запрос из‑за неверной подписи. **Это проблема бэкенда**, а не Flutter.

## Подробная инструкция для бэкенда

**См. [PAYANYWAY_MNT_SIGNATURE_WEB_BACKEND.md](PAYANYWAY_MNT_SIGNATURE_WEB_BACKEND.md)** — там точная формула из Android SDK, псевдокод (PHP, Node.js) и примеры.

Кратко: `md5(MNT_ID + MNT_TRANSACTION_ID + MNT_AMOUNT + MNT_CURRENCY_CODE + MNT_TEST_MODE + MNT_ACCOUNT_CODE)` — конкатенация без разделителей, MNT_AMOUNT в формате `"199.00"`.

## Что проверить на бэкенде

1. **Правильный секретный ключ** — тот же, что в ЛК MONETA.ru
2. **Порядок параметров** — строго по алфавиту (см. [документацию Moneta](https://docs.moneta.ru/assistant/v1/widget/))
3. **Формат чисел** — `MNT_AMOUNT` без лишних символов (например, `199`, не `199.00`)
4. **Кодировка URL** — `MNT_SUCCESS_URL` и `MNT_FAIL_URL` в URL-encoded виде в подписи, если это требуется

## Ссылки

- [MNT_SIGNATURE в документации Moneta](https://docs.moneta.ru/tags/mnt_signature/index.html)
- [ assistant.widget параметры](https://docs.moneta.ru/assistant/v1/widget/)
- [Код проверки в android_basic_settings.ini](../../android/app/src/main/assets/android_basic_settings.ini) — `monetasdk_account_code`
