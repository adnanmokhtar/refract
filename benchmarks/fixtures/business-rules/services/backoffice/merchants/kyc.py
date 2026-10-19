"""KYC review: the risk team approves or rejects a merchant before payouts are enabled."""
from merchants.models import KycStatus, MerchantAccount


def approve(merchant_id: int, reviewer: str) -> None:
    merchant = MerchantAccount.objects.get(pk=merchant_id)
    if merchant.kyc_status != KycStatus.PENDING:
        raise ValueError("already reviewed")
    merchant.kyc_status = KycStatus.APPROVED
    merchant.save(update_fields=["kyc_status"])


def reject(merchant_id: int, reviewer: str) -> None:
    merchant = MerchantAccount.objects.get(pk=merchant_id)
    if merchant.kyc_status != KycStatus.PENDING:
        raise ValueError("already reviewed")
    merchant.kyc_status = KycStatus.REJECTED
    merchant.save(update_fields=["kyc_status"])
