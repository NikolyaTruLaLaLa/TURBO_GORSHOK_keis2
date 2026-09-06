# NovaPay_Payout_API Integration Guide

## Авторизация
### ApiKeyAuth
- Тип: apiKey
- Параметр: `X-API-Key` (in: header)
- Хранение: `providers.credentials` (encrypted)

## Методы
| Метод | Endpoint | Назначение | Idempotency |
|-------|----------|------------|-------------|
| createPayout | /payouts | Создать выплату | Idempotency-Key header |
| getPayoutStatus | /payouts/{payout_id} | Получить статус выплаты | — |
| cancelPayout | /payouts/{payout_id}/cancel | Отменить выплату | — |
| payoutWebhook | /webhooks/payout | Webhook уведомление о смене статуса | Idempotency-Key header |
| getBalance | /balance | Баланс провайдера | — |


## Маппинг статусов
| Provider | Space Payments |
|----------|----------------|
| pending | in_progress |
| processing | in_progress |
| completed | approved |
| failed | rejected |
| cancelled | rejected |


## Обработка ошибок
| HTTP | Provider code | Действие |
|------|---------------|----------|
| 400 | error.code | reject |
| 401 | error.code | alert ops, block provider |
| 402 | error.code | retry later |
| 409 | error.code | retry |
| 422 | error.code | reject |
| 429 | error.code | retry with backoff |
| 500 | error.code | retry, alert ops |
| 404 | error.code | retry |


## ProviderGateway config
{ "external_method": "sbp_payout", "gateway": "RUB_SBP_WITHDRAW" }

## Webhook signature
HMAC-SHA256(body, callback_secret) → hex → X-NovaPay-Signature