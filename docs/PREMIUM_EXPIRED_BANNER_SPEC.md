# Баннер «Подписка закончилась» — спецификация

---

## 1. Когда показываем баннер

| Условие | Пояснение |
|---------|-----------|
| Была активная подписка → стала неактивна | Переход `has_active_subscription: true` → `false` (подписка истекла по `subscription_ends_at`) |
| Не показываем при `networkUnavailable` | Если нет сети — не путаем с истечением подписки |
| Не показываем при `isUnauthorized` | Для гостя или неавторизованного — другие экраны |
| Только один раз за «событие истечения» | После закрытия или отображения — не показываем снова до следующего истечения |

## 2. Когда не показываем

| Случай | Причина |
|--------|---------|
| Пользователь никогда не имел подписку | Баннер «Подписка закончилась» вводит в заблуждение |
| Пробный период истёк, но подписки не было | Текст «Оформить подписку» достаточен |
| Подписка отменена, но ещё активна | `subscriptionCancelled: true`, `hasActiveSubscription: true` — доступ есть до конца периода |
| Баннер уже показывали для этого истечения | Флаг `subscription_expired_banner_shown` сбрасывается только при новой подписке |

## 3. Как определяем «подписка истекла»

**1. Предпочтительный метод — бэкенд:** поле `subscription_recently_expired` в `GET /api/premium/status`.

- Бэкенд выставляет `true`, если есть запись в `premium_subscriptions` с `expires_at < now` и нет активной подписки.
- Работает при любом устройстве, переустановке, очистке кэша — источник правды в БД. См. [BACKEND_PREMIUM_API_REQUIREMENTS.md](./BACKEND_PREMIUM_API_REQUIREMENTS.md).

**2. Fallback — клиент:** сравнение закэшированного статуса с новым ответом API.

1. Перед запросом `GET /api/premium/status` читаем кэш.
2. В кэше было `has_active_subscription: true`.
3. API вернул `has_active_subscription: false`.
4. → Считаем, что подписка только что истекла.

**Ограничение fallback:** после переустановки, входа с другого устройства или очистки данных кэша нет — баннер не покажем без поддержки бэкенда. Поэтому `subscription_recently_expired` рекомендуется реализовать на бэкенде.

## 4. Учёт показа (чтобы не спамить)

| Хранилище | Ключ | Значение |
|-----------|------|----------|
| SharedPreferences | `subscription_expired_banner_shown` | `true` — баннер уже показывали для текущего истечения |

**Логика:**
- При переходе active→expired: если `subscription_expired_banner_shown != true` → показываем баннер, выставляем `true`.
- Когда пользователь снова оформит подписку (`has_active_subscription: true`) → сбрасываем `subscription_expired_banner_shown = false`. При следующем истечении баннер покажем снова.
- При закрытии баннера пользователем — флаг уже `true`, повторно не показываем.

## 5. Где показываем

| Экран | Когда |
|-------|-------|
| **ProfileScreen** | `subscriptionJustExpired == true`, над карточкой подписки |
| **ClimbingLogScreen** (paywall) | `subscriptionJustExpired == true` и `showPaywall == true`, над ClimbingLogPremiumStub |

В обоих случаях баннер — мягкий призыв: «Подписка закончилась. Оформите снова».

## 6. Поведение баннера

- Текст: «Подписка закончилась. Оформите снова» (или аналогично).
- Иконка: `Icons.workspace_premium` или `Icons.schedule`.
- Цвет: `mutedGold` (Premium-акцент), не ошибка.
- Кнопка «Оформить» — переход на PremiumPaymentScreen.
- Кнопка «Закрыть» — скрыть, флаг `subscription_expired_banner_shown` уже установлен.

## 7. Расширение API (рекомендуется)

Для надёжного определения при новом устройстве/переустановке — в `GET /api/premium/status`:

| Поле | Тип | Описание |
|------|-----|----------|
| `subscription_recently_expired` | boolean | `true` — подписка истекла, показывать баннер «Подписка закончилась» |

**Логика на бэкенде:** `true`, если есть запись в `premium_subscriptions` с `expires_at < now` и нет активной подписки (источник правды — БД, а не клиентский кэш).

---

## 8. Реализация

- **PremiumStatus**: поле `subscriptionJustExpired` (по умолчанию `false`).
- **PremiumSubscriptionService**: 
  - при `getStatus()` сравниваем кэш с ответом API;
  - при переходе active→expired выставляем `subscriptionJustExpired: true` и флаг `subscription_expired_banner_shown`;
  - при новой подписке сбрасываем флаг.
- **ProfileScreen** и **ClimbingLogScreen** (paywall): `TopNotificationBanner.subscriptionExpired` с кнопкой «Оформить» и «Закрыть».
- Локальное состояние `_expiredBannerDismissed` — скрыть баннер в текущей сессии до обновления статуса.
