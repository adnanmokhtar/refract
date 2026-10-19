"""Merchant onboarding: the owner confirms the phone number with a one-time code sent at sign-up."""
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from merchants.models import MerchantAccount


def confirm_phone(merchant_id: int, code: str) -> None:
    merchant = MerchantAccount.objects.get(pk=merchant_id)
    if merchant.otp_expires_at < timezone.now():
        raise ValidationError("Expired verification code. Please contact support.")
    if merchant.otp_code != code:
        raise ValidationError("Wrong code")
