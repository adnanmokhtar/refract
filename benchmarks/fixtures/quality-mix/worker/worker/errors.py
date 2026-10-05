class ProviderError(Exception):
    """The payment provider answered with an error."""


class BillingError(Exception):
    """A renewal could not be billed; carries the provider's error as __cause__."""
