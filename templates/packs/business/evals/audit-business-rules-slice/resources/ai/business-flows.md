# Declared lifecycles

## Order

- pending_payment -> paid -> fulfilling -> shipped -> delivered
- pending_payment -> cancelled
- paid -> cancelled
- fulfilling -> cancelled
- delivered -> return_requested -> refunded
- paid -> disputed -> paid

## Invoice

- draft -> issued -> paid
- issued -> credited
- draft -> void

## Subscription

- trialing -> active -> past_due -> cancelled
- active -> paused -> active
- active -> cancelled
