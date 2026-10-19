"""Self-service privacy requests from the customer account page."""
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from privacy.erasure import pseudonymise_customer


class GdprRequestViewSet(viewsets.ViewSet):
    @action(detail=False, methods=["post"], url_path="erase-me")
    def erase_me(self, request):
        pseudonymise_customer(request.user.customer_id)
        return Response(status=202)
