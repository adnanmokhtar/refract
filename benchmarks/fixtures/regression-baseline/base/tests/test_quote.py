from pricing.quote import quote


def test_single_line_total():
    q = quote({"id": "o-1", "lines": [{"sku": "a", "unit_cents": 2000, "qty": 1}]})
    assert q["total_cents"] == 2165


def test_discount_applies_at_threshold():
    q = quote({"id": "o-2", "lines": [{"sku": "a", "unit_cents": 5000, "qty": 2}]})
    assert q["discount_cents"] == 1000
