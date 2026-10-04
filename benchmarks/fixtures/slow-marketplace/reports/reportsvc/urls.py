from django.urls import include, path

urlpatterns = [
    path("", include("refunds.urls")),
]
