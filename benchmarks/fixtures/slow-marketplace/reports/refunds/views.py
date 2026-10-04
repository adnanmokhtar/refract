from decimal import Decimal

from rest_framework import generics
from rest_framework.pagination import CursorPagination
from rest_framework.response import Response
from rest_framework.views import APIView

from . import fx
from .models import Refund
from .permissions import IsFinanceStaff, IsStoreMember
from .serializers import RefundSerializer


class RefundCursorPagination(CursorPagination):
    page_size = 50
    ordering = ("-created_at", "-id")


class RefundListView(generics.ListAPIView):
    """GET /refunds/?status=&currency= — finance's refund list; the page has an "Export CSV"
    button that saves exactly what the list returned."""

    serializer_class = RefundSerializer
    permission_classes = [IsFinanceStaff]

    def get_queryset(self):
        qs = Refund.objects.order_by("-created_at")
        status = self.request.query_params.get("status")
        if status:
            qs = qs.filter(status=status)
        currency = self.request.query_params.get("currency")
        if currency:
            qs = qs.filter(currency=currency.upper())
        return qs


class StoreRefundListView(generics.ListAPIView):
    """GET /stores/<uuid:store_id>/refunds/ — a seller's own refunds in the seller dashboard."""

    serializer_class = RefundSerializer
    pagination_class = RefundCursorPagination
    permission_classes = [IsStoreMember]

    def get_queryset(self):
        return (
            Refund.objects.filter(order__store_id=self.kwargs["store_id"])
            .select_related("order__store")
            .order_by("-created_at", "-id")
        )


class RefundSummaryView(APIView):
    """GET /refunds/summary/?day=YYYY-MM-DD — settled refunds per currency, plus the EUR
    equivalent at that day's rate, for the finance dashboard's daily tile."""

    permission_classes = [IsFinanceStaff]

    def get(self, request):
        day = fx.parse_day(request.query_params.get("day"))
        totals = fx.settled_totals(day)
        eur = sum((Decimal(str(t["amount"])) * fx.rate("EUR", t["currency"], day) for t in totals), Decimal("0"))
        return Response({"day": day.isoformat(), "totals": totals, "eur_equivalent": str(eur.quantize(Decimal("0.01")))})
