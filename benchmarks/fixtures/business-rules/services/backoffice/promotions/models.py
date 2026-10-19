from django.db import models


class Campaign(models.Model):
    store_id = models.CharField(max_length=40)
    name = models.CharField(max_length=200)
    starts_on = models.DateField()
    ends_on = models.DateField()
    percent_off = models.DecimalField(max_digits=5, decimal_places=2)
