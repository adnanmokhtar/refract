# Recipient notifications

A parcel's recipient gets an SMS when the label is created, when the parcel is out for delivery,
when it is delivered and when it hits an exception. Each message links to the tracking page
(`PUBLIC_ORIGIN/t/<code>`), where the assistant answers follow-up questions.

## Flow

1. A shipment status change is written to `outbox` with the shipment in one transaction.
2. `OutboxRelay` moves it to BullMQ; the status projector publishes to `qw-status-events`.
3. `StatusEventsConsumer` long-polls the queue and calls `NotificationsService`, which sends
   through `SmsService` (Twilio).

## Volume and cost

About 310,000 parcels a month, so roughly 1.1 million messages with exceptions included. A UK
message costs $0.0463 per message at our tier, and most messages fit one segment; keep the
templates under 160 characters, because a second segment doubles the price of that message.
