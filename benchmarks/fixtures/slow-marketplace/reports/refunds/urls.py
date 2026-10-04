from django.urls import path

from . import views

urlpatterns = [
    path("refunds/", views.RefundListView.as_view()),
    path("refunds/summary/", views.RefundSummaryView.as_view()),
    path("stores/<uuid:store_id>/refunds/", views.StoreRefundListView.as_view()),
]
