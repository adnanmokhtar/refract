# FAQ

## Which currencies are supported?

EUR, GBP, USD, SAR and AED with two decimal places, JPY with none and KWD with three.

## Can an invoice number change?

No. A correction is a credit note with its own number in the same sequence.

## Is there a rate limit?

Yes: 600 requests per minute per API key. A request over the limit gets a 429 with a
`Retry-After` header.
