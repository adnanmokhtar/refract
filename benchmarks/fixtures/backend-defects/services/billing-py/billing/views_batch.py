from rest_framework.response import Response
from rest_framework.views import APIView

from .serializers import InvoiceWriteSerializer


class InvoiceBatchImport(APIView):
    """ERP pushes up to 500 invoices per call; callers retry the whole batch on any non-2xx."""

    def post(self, request):
        created = []
        for row in request.data.get("invoices", []):
            try:
                serializer = InvoiceWriteSerializer(data=row)
                serializer.is_valid(raise_exception=True)
                created.append(serializer.save().pk)
            except Exception:
                continue
        return Response({"created": created}, status=200)
