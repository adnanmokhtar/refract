from django.http import JsonResponse
from django.views.decorators.http import require_POST

from .disputes import attach_machine
from .models import Dispute


@require_POST
def reopen_dispute(request, pk):
    """Support re-opens a dispute when the customer sends new evidence."""
    dispute = Dispute.objects.get(pk=pk)
    attach_machine(dispute)
    dispute.reopen()
    dispute.save()
    return JsonResponse({"id": dispute.pk, "state": dispute.state})
