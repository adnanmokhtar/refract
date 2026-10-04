from django.contrib.auth import get_user_model
from rest_framework.authentication import BaseAuthentication


class GatewayHeaderAuthentication(BaseAuthentication):
    """The internal gateway authenticates staff and forwards X-Staff-User / X-Staff-Groups."""

    def authenticate(self, request):
        username = request.headers.get("X-Staff-User")
        if not username:
            return None
        user, _ = get_user_model().objects.get_or_create(username=username)
        user.gateway_groups = set(filter(None, request.headers.get("X-Staff-Groups", "").split(",")))
        return (user, None)
