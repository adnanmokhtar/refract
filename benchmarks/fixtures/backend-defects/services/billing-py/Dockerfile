FROM python:3.13-slim
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
USER 10001
CMD ["gunicorn", "billing_service.wsgi", "--bind", "0.0.0.0:8000", "--workers", "4"]
