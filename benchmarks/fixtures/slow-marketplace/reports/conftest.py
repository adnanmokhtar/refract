import pytest
from rest_framework.test import APIClient


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def finance_client(api_client, django_user_model):
    user = django_user_model.objects.create_user(username="finance", password=None)
    user.groups.create(name="finance")
    api_client.force_authenticate(user)
    return api_client
