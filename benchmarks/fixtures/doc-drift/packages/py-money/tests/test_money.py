from py_money import allocate, format_amount, to_minor


def test_to_minor_rounds_half_even():
    assert to_minor("10.50", "EUR") == 1050
    assert to_minor(1.005, "EUR") == 100


def test_format_amount_uses_the_prefix():
    assert format_amount(1050, "EUR") == "€10.50"
    assert format_amount(-500, "JPY") == "-¥500"


def test_allocate_keeps_every_minor_unit():
    assert allocate(100, [1, 1, 1]) == [34, 33, 33]
    assert sum(allocate(1001, [3, 7])) == 1001
