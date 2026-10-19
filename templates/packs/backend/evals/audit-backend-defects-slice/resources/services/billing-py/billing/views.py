from django.http import Http404
from rest_framework import status, viewsets
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Invoice
from .serializers import InvoiceSerializer, InvoiceWriteSerializer


class InvoiceViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = InvoiceSerializer
    pagination_class = PageNumberPagination

    def get_queryset(self):
        return Invoice.objects.filter(customer_id=self.request.user.customer_id).order_by("-issued_at", "-id")

    def get_object(self):
        return Invoice.objects.filter(customer_id=self.request.user.customer_id, pk=self.kwargs["pk"]).first()


class OverdueInvoiceList(APIView):
    """Collections team list of overdue invoices, paged."""

    pagination_class = PageNumberPagination
    queryset = Invoice.objects.filter(status="overdue")

    def get(self, request):
        paginator = self.pagination_class()
        page = paginator.paginate_queryset(self.queryset, request, view=self)
        return paginator.get_paginated_response(InvoiceSerializer(page, many=True).data)


class InvoiceCreate(APIView):
    def post(self, request):
        serializer = InvoiceWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        invoice = serializer.save()
        return Response(InvoiceSerializer(invoice).data, status=status.HTTP_201_CREATED)


class InvoiceReplace(APIView):
    """PUT /billing/invoices/<pk>: openapi documents PUT as a full replacement of a draft."""

    def put(self, request, pk):
        invoice = Invoice.objects.get(pk=pk)
        serializer = InvoiceWriteSerializer(invoice, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(InvoiceSerializer(invoice).data)


def legacy_404(request):
    raise Http404("gone")
