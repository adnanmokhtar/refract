from django.db import models


class KycStatus(models.TextChoices):
    PENDING = "pending", "Pending"
    APPROVED = "approved", "Approved"
    REJECTED = "rejected", "Rejected"


KYC_TRANSITIONS = {
    KycStatus.PENDING: [KycStatus.APPROVED, KycStatus.REJECTED],
    KycStatus.APPROVED: [],
    KycStatus.REJECTED: [],
}


class Customer(models.Model):
    email = models.EmailField()
    name = models.CharField(max_length=200)
    phone = models.CharField(max_length=32, blank=True)
    marketing_opt_in = models.BooleanField(default=False)


class CompanyProfile(models.Model):
    legal_name = models.CharField(max_length=200)
    vat_number = models.CharField(max_length=32)


class MerchantAccount(models.Model):
    name = models.CharField(max_length=200)
    kyc_status = models.CharField(max_length=16, choices=KycStatus.choices, default=KycStatus.PENDING)
    otp_code = models.CharField(max_length=8, blank=True)
    otp_expires_at = models.DateTimeField(null=True)
