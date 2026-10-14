import base64
import json

from django.core.serializers.json import DjangoJSONEncoder
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Invoice
from .serializers import InvoiceSerializer


def encode_cursor(updated_at, pk):
    return base64.urlsafe_b64encode(json.dumps({"u": updated_at, "id": pk}, cls=DjangoJSONEncoder).encode()).decode()


class InvoiceChangesFeed(APIView):
    """ERP sync: invoices changed since the cursor, oldest first (keyset on updated_at, id)."""

    def get(self, request):
        cursor = request.query_params.get("cursor")
        qs = Invoice.objects.order_by("updated_at", "id")
        if cursor:
            c = json.loads(base64.urlsafe_b64decode(cursor))
            qs = qs.filter(updated_at__gt=c["u"]) | qs.filter(updated_at=c["u"], id__gt=c["id"])
        rows = list(qs[:200])
        next_cursor = encode_cursor(rows[-1].updated_at, rows[-1].pk) if rows else None
        return Response({"results": InvoiceSerializer(rows, many=True).data, "next": next_cursor})
