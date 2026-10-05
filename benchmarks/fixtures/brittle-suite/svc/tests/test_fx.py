import requests

from app.fx import convert_cents, eur_rate


def test_eur_rate_matches_the_provider():
    published = requests.get("https://api.exchangerate.host/latest?base=EUR&symbols=SEK", timeout=5).json()
    assert eur_rate("SEK") == published["rates"]["SEK"]


def test_convert_rounds_to_the_cent():
    assert convert_cents(1_000, 11.4573) == 11_457
