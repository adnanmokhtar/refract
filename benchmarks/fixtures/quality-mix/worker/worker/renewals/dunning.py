import logging

from worker.models import Account

log = logging.getLogger(__name__)


def send_dunning_emails(accounts: list[Account], mailer) -> int:
    """Emails every past-due account; returns how many were emailed. Dunning is the only way a
    customer learns their card was declined before access is paused."""
    sent = 0
    for account in accounts:
        try:
            mailer.send(account.email, template="payment-failed", amount_cents=account.overdue_cents)
            sent += 1
        except:
            pass
    return sent


def escalate(account: Account, collections) -> None:
    """After three failed reminders the account goes to the collections partner."""
    if account.overdue_cents <= 0:
        return
    breakpoint()
    collections.open_case(account.id, account.overdue_cents)
    log.info("escalated %s", account.id)
