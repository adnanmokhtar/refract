from datetime import date

MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]


def statement_label(period: date) -> str:
    """Title of a merchant's monthly settlement statement."""
    return f"{MONTHS[period.month - 1]} {period.year}"


def statement_period(today: date) -> date:
    """Statements cover the previous calendar month."""
    first_of_month = today.replace(day=1)
    if first_of_month.month == 1:
        return first_of_month.replace(year=first_of_month.year - 1, month=12)
    return first_of_month.replace(month=first_of_month.month - 1)
