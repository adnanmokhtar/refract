"""Finance back-office API for invoices."""
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from invoicing.models import Invoice


class InvoiceAdminViewSet(viewsets.ViewSet):
    @action(detail=True, methods=["post"], url_path="correct-total")
    def correct_total(self, request, pk=None):
        Invoice.objects.filter(pk=pk).update(total=request.data["total"], tax_total=request.data["tax_total"])
        return Response(status=204)
