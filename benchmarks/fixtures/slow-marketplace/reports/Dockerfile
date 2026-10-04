FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN useradd --uid 10001 app && chown -R app /app
USER app
EXPOSE 8000
CMD ["gunicorn", "-c", "gunicorn.conf.py", "reportsvc.wsgi"]
