from rest_framework.permissions import BasePermission


class IsFinanceStaff(BasePermission):
    def has_permission(self, request, view):
        return "finance" in getattr(request.user, "gateway_groups", set())


class IsStoreMember(BasePermission):
    def has_permission(self, request, view):
        stores = getattr(request.user, "gateway_groups", set())
        return f"store:{view.kwargs.get('store_id')}" in stores
