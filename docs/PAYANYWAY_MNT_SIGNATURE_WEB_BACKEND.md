# MNT_SIGNATURE — инструкция для веб-бэкенда (create-payment)

Документ описывает **точно** то, как Android SDK формирует подпись. Веб-бэкенд **должен повторить эту же логику** для эндпоинта `POST /api/premium/create-payment`, чтобы PayAnyWay принимал запросы.

---

## 1. Откуда берутся значения

| Параметр | Источник | Пример |
|----------|----------|--------|
| **MNT_ID** | Номер расширенного счёта из ЛК MONETA.ru | `78715768` |
| **MNT_ACCOUNT_CODE** | Код проверки целостности из ЛК (секрет) | `12345` |
| **MNT_TEST_MODE** | `"0"` = боевой, `"1"` = тест | `0` |

Значения должны совпадать с `android/app/src/main/assets/android_basic_settings.ini`:
- `monetasdk_account_id` → MNT_ID
- `monetasdk_account_code` → MNT_ACCOUNT_CODE (секрет)
- `monetasdk_test_mode` → MNT_TEST_MODE

---

## 2. Формула подписи (создание payment_url)

**Источник:** `MonetaSdk.java`, строки 88–90.

```
MNT_SIGNATURE = md5(строка_для_хэша)
```

Строка для хэша — **конкатенация без разделителей** в таком порядке:

| № | Параметр | Описание |
|---|----------|----------|
| 1 | MNT_ID | Номер счёта |
| 2 | MNT_TRANSACTION_ID | order_id заказа |
| 3 | MNT_AMOUNT | Сумма **с двумя знаками после запятой**, десятичный разделитель — точка |
| 4 | MNT_CURRENCY_CODE | Код валюты, например `RUB` |
| 5 | MNT_TEST_MODE | `"0"` или `"1"` |
| 6 | MNT_ACCOUNT_CODE | Секретный код из ЛК |

**Пример:**
```
account_id    = "78715768"
order_id      = "premium_301_1771332720"
amount        = "199.00"
currency      = "RUB"
test_mode     = "0"
account_code  = "12345"

Строка для md5: "78715768" + "premium_301_1771332720" + "199.00" + "RUB" + "0" + "12345"
              = "78715768premium_301_1771332720199.00RUB012345"

MNT_SIGNATURE = md5("78715768premium_301_1771332720199.00RUB012345")
```

---

## 3. Формат MNT_AMOUNT

- **Обязательно** два знака после запятой: `199.00`, не `199` и не `199.0`
- Разделитель — **точка** (`.`), не запятая
- В Android: `String.format("%.2f", amount).replace(",", ".")`

---

## 4. Какие параметры НЕ входят в подпись

Следующие параметры **не участвуют** в расчёте MNT_SIGNATURE при создании payment_url:

- MNT_SUCCESS_URL
- MNT_FAIL_URL
- MNT_DESCRIPTION
- Любые другие параметры, кроме перечисленных в п. 2

---

## 5. Псевдокод для бэкенда (PHP)

```php
function computeMntSignature(string $accountId, string $orderId, float $amount,
    string $currency, string $testMode, string $accountCode): string {
    $amountStr = number_format($amount, 2, '.', '');
    $concat = $accountId . $orderId . $amountStr . $currency . $testMode . $accountCode;
    return strtolower(md5($concat));
}
```

---

## 6. Псевдокод для бэкенда (Node.js)

```javascript
function computeMntSignature(accountId, orderId, amount, currency, testMode, accountCode) {
  const amountStr = Number(amount).toFixed(2);
  const concat = accountId + orderId + amountStr + currency + testMode + accountCode;
  return require('crypto').createHash('md5').update(concat).digest('hex').toLowerCase();
}
```

---

## 7. Сборка payment_url

Базовый URL: `https://service.moneta.ru/assistant.widget` (prod) или `https://demo.moneta.ru/assistant.widget` (test).

Минимальный набор query-параметров:

```
MNT_ID=78715768
MNT_TRANSACTION_ID=premium_301_1771332720
MNT_AMOUNT=199.00
MNT_CURRENCY_CODE=RUB
MNT_TEST_MODE=0
MNT_SUCCESS_URL=<url-encoded success url>
MNT_FAIL_URL=<url-encoded fail url>
MNT_SIGNATURE=<вычисленная подпись>
```

Опционально: `MNT_DESCRIPTION` и др. по документации Moneta.

---

## 8. Проверка подписи во входящем webhook (Pay URL)

Moneta отправляет уведомление об оплате на Pay URL с параметрами, включая `MNT_SIGNATURE`.

**Формула проверки входящего запроса** (из [документации Moneta](https://docs.moneta.ru/payments/payment-notification/index.html)):

Для **ответа** на webhook (что мы отправляем Moneta) подпись считается так:
```
MNT_SIGNATURE = md5(MNT_RESULT_CODE + MNT_ID + MNT_TRANSACTION_ID + MNT_OPERATION_ID + MNT_ACCOUNT_CODE)
```

Где `MNT_RESULT_CODE = 200` при успехе.

Для **проверки** входящего webhook: Moneta присылает свои параметры. Сверьте подпись по формуле из [документации](https://docs.moneta.ru/payments/payment-notification/index.html) и своему секретному коду.

---

## 9. Ссылки

- [MNT_SIGNATURE (Moneta)](https://docs.moneta.ru/tags/mnt_signature/index.html)
- [Уведомление об оплате](https://docs.moneta.ru/payments/payment-notification/index.html)
- [Код Android SDK](../../android/app/src/main/java/ru/integrationmonitoring/monetasdkapp/MonetaSdk.java) — строки 88–90, 115–131
