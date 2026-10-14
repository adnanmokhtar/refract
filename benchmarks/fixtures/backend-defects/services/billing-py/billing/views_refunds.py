from rest_framework.exceptions import NotFound
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Refund


class RefundDetail(APIView):
    def get(self, request, pk):
        try:
            refund = Refund.objects.get(pk=pk, invoice__customer_id=request.user.customer_id)
        except Refund.DoesNotExist:
            raise NotFound("refund not found")
        return Response({"id": refund.pk, "state": refund.state, "amount": str(refund.amount)})
