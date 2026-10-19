-- payouts land in the raw dataset from the PSP's settlement API
select payout_id, merchant_id, iban, amount_cents, paid_out_at
from analytics_raw.payouts
