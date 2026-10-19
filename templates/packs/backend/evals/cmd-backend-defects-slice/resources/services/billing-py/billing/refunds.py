from django.http import JsonResponse
from django.views.decorators.http import require_POST
from transitions import Machine

from .models import Refund
from .psp import refund_capture

REFUND_STATES = ["requested", "approved", "paid", "rejected"]
REFUND_TRANSITIONS = [
    {"trigger": "approve", "source": "requested", "dest": "approved"},
    {"trigger": "reject", "source": "requested", "dest": "rejected"},
    {"trigger": "mark_paid", "source": "approved", "dest": "paid"},
]


@require_POST
def approve_refund(request, pk):
    refund = Refund.objects.select_for_update().get(pk=pk)
    Machine(model=refund, states=REFUND_STATES, transitions=REFUND_TRANSITIONS, initial=refund.state,
            model_attribute="state", ignore_invalid_triggers=True)
    refund.approve()
    psp_id = refund_capture(refund.invoice_id, refund.amount)
    refund.psp_refund_id = psp_id
    refund.save()
    return JsonResponse({"id": refund.pk, "state": refund.state, "psp_refund_id": psp_id})
