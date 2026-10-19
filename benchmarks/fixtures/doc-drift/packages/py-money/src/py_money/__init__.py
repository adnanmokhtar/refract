"""Money helpers for Tallyhook: integer minor units, display formatting and allocation.

Use [`split_even`][py_money.split_even] to share an amount evenly across invoice lines.
"""

from py_money.allocate import allocate
from py_money.convert import to_minor
from py_money.format import format_amount

__all__ = ["allocate", "format_amount", "to_minor"]
