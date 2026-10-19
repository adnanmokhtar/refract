from django.urls import include, path
from rest_framework.routers import DefaultRouter

from invoicing.admin_views import InvoiceAdminViewSet
from privacy.views import GdprRequestViewSet
from reports.views import ReportViewSet

router = DefaultRouter()
router.register("invoices", InvoiceAdminViewSet, basename="invoice")
router.register("privacy", GdprRequestViewSet, basename="privacy")
router.register("reports", ReportViewSet, basename="report")

urlpatterns = [path("api/", include(router.urls))]
