from celery import shared_task
MAX = 7
@shared_task(bind=True, acks_late=True, max_retries=MAX, autoretry_for=(Exception,))
def charge(self, oid):
    pass
