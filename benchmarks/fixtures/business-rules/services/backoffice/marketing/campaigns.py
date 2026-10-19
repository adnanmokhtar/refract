"""Promotional e-mail campaigns sent by the back office on the merchant's behalf."""
from django.core.mail import EmailMessage, get_connection


def send_campaign(campaign, customers) -> int:
    connection = get_connection()
    sent = 0
    for customer in customers:
        if not customer.marketing_opt_in:
            continue
        msg = EmailMessage(subject=campaign.subject, body=campaign.html, to=[customer.email], connection=connection)
        msg.content_subtype = "html"
        sent += msg.send()
    return sent
