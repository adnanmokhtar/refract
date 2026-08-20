"""Outbound email. Used for task reminders today; deal-stage notifications later."""

import smtplib
from email.message import EmailMessage

from ..config import settings


def send(to: str, subject: str, body: str) -> None:
    message = EmailMessage()
    message["To"] = to
    message["From"] = "smallcrm@localhost"
    message["Subject"] = subject
    message.set_content(body)

    with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
        server.send_message(message)


def send_task_reminder(to: str, task_title: str, due_on: str) -> None:
    send(to, f"Reminder: {task_title}", f"{task_title} is due on {due_on}.")
