"""Report endpoints for account managers."""
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from reports.tasks import generate_report


class ReportViewSet(viewsets.ViewSet):
    @action(detail=False, methods=["post"], url_path="orders-export")
    def orders_export(self, request):
        merchant = request.user.merchant
        generate_report.apply_async(args=[merchant.id], kwargs={"kind": "orders_export"})
        return Response({"detail": "Your export is being prepared."}, status=202)
