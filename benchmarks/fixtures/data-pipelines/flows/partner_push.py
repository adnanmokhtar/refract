"""Pushes the day's settled orders to the logistics partner."""
import requests
from prefect import flow, task


@task(retries=3, retry_delay_seconds=30)
def push_orders(orders):
    response = requests.post("https://partner.example/api/orders", json=orders, timeout=30)
    response.raise_for_status()


@flow
def partner_push(orders):
    push_orders(orders)
