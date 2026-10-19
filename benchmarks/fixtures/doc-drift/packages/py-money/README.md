# py-money

Integer minor-unit money helpers for Tallyhook's Python jobs. Python 3.12+.

```bash
pip install py-money
```

## Converting amounts

```pycon
>>> from py_money import to_minor
>>> to_minor("10.50", "EUR")
1050
>>> to_minor(1.005, "EUR")
101

```

## Formatting

```pycon
>>> from py_money import format_amount
>>> format_amount(1050, "EUR")
'€10.50'

```

## Allocating

`allocate(amount_minor, ratios)` splits an amount across ratios and hands the leftover minor
units to the first shares, so the parts always add up to the whole.
