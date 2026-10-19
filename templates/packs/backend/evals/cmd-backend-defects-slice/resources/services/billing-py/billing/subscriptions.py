from rest_framework.exceptions import APIException
from transitions import Machine

from .models import Subscription


class IllegalTransition(APIException):
    status_code = 409
    default_code = "illegal_state"


SUB_STATES = ["active", "paused", "cancelled"]
SUB_TRANSITIONS = [
    {"trigger": "pause", "source": "active", "dest": "paused"},
    {"trigger": "resume", "source": "paused", "dest": "active"},
    {"trigger": "cancel", "source": ["active", "paused"], "dest": "cancelled"},
]


def cancel_subscription(sub: Subscription) -> Subscription:
    """The trigger returns False on an illegal event (ignore_invalid_triggers) and we answer 409."""
    Machine(model=sub, states=SUB_STATES, transitions=SUB_TRANSITIONS, initial=sub.state,
            model_attribute="state", ignore_invalid_triggers=True)
    if not sub.cancel():
        raise IllegalTransition(f"cannot cancel a {sub.state} subscription")
    sub.save()
    return sub
