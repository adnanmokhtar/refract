import pytest

from app.validation import ValidationError, validate_refund_request


def test_accepts_a_euro_refund():
    assert validate_refund_request({"currency": "EUR", "amount_cents": 1_000})["currency"] == "EUR"


def test_names_the_unsupported_currency():
    try:
        validate_refund_request({"currency": "XYZ", "amount_cents": 1_000})
    except ValidationError as e:
        assert "XYZ" in str(e)


def test_refuses_a_zero_amount():
    with pytest.raises(ValidationError, match="positive integer"):
        validate_refund_request({"currency": "EUR", "amount_cents": 0})
