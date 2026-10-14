from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed


class ServicePrincipal:
    is_authenticated = True

    def __init__(self, customer_id):
        self.customer_id = customer_id


class ServiceTokenAuthentication(BaseAuthentication):
    def authenticate(self, request):
        token = request.headers.get("Authorization", "")
        if not token.startswith("Bearer "):
            raise AuthenticationFailed("missing token")
        return ServicePrincipal(request.headers.get("X-Customer-Id")), token
