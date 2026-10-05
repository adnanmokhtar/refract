from datetime import date, datetime

from freezegun import freeze_time

from app.statements import statement_label, statement_period


def test_labels_the_current_month_statement():
    assert statement_label(datetime.now().date()) == "October 2026"


def test_labels_a_fixed_month():
    assert statement_label(date(2026, 2, 1)) == "February 2026"


def test_period_wraps_back_to_december():
    assert statement_period(date(2026, 1, 15)) == date(2025, 12, 1)


def test_period_is_the_previous_month_mid_month():
    assert statement_period(date(2026, 7, 9)) == date(2026, 6, 1)


@freeze_time("2026-03-31 23:30:00")
def test_period_on_the_last_evening_of_a_month():
    assert statement_period(datetime.now().date()) == date(2026, 2, 1)
