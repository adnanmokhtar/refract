class User(models.Model):
    email = models.EmailField(unique=True)
    class Meta:
        constraints = [models.UniqueConstraint(fields=['tenant','slug'], name='u')]
