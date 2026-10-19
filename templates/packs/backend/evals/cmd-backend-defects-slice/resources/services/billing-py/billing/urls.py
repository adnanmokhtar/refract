from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import InvoiceCreate, InvoiceReplace, InvoiceViewSet, OverdueInvoiceList
from .views_batch import InvoiceBatchImport
from .views_feed import InvoiceChangesFeed
from .views_refunds import RefundDetail
from .views_disputes import reopen_dispute
from .refunds import approve_refund

router = DefaultRouter()
router.register("invoices", InvoiceViewSet, basename="invoice")

urlpatterns = router.urls + [
    path("invoices-overdue/", OverdueInvoiceList.as_view()),
    path("invoices-new/", InvoiceCreate.as_view()),
    path("invoices/<int:pk>/replace/", InvoiceReplace.as_view()),
    path("invoices-batch/", InvoiceBatchImport.as_view()),
    path("invoices-changes/", InvoiceChangesFeed.as_view()),
    path("refunds/<int:pk>/", RefundDetail.as_view()),
    path("refunds/<int:pk>/approve/", approve_refund),
    path("disputes/<int:pk>/reopen/", reopen_dispute),
]
