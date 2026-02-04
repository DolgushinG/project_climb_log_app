# API Checkout — эндпоинты для мобильного приложения

Мобильное приложение вызывает следующие эндпоинты (все с Bearer token):

| Метод | URL | Назначение |
|-------|-----|------------|
| GET | `/api/event/{id}/checkout` | Данные checkout |
| POST | `/api/event/{id}/save-package` | Сохранить выбранный пакет |
| POST | `/api/event/{id}/check-promo-code` | Применить промокод |
| POST | `/api/event/{id}/cancel-promo-code` | Отменить промокод |
| POST | `/api/event/{id}/cancel-take-part` | Отмена регистрации (при таймере 0) |
| POST | `/api/event/{id}/upload-receipt` | Загрузка чека (multipart) |
| POST | `/api/event/{id}/payment-to-place` | Оплата на месте |

Полная спецификация — в описании задачи.
