from worker.models import Account


def find_account(accounts: dict[str, Account], account_id: str) -> Account | None:
    return accounts.get(account_id)


def reminder_address(accounts: dict[str, Account], account_id: str) -> str:
    """Where the dunning reminder goes. Accounts deleted mid-cycle are no longer in the map."""
    return find_account(accounts, account_id).email  # type: ignore[union-attr]
