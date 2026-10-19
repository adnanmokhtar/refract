FROM python:3.12-slim
WORKDIR /srv
RUN pip install --no-cache-dir uv
COPY pyproject.toml ./
RUN uv pip install --system -r pyproject.toml
COPY app ./app
ENV PYTHONUNBUFFERED=1
ENV OTEL_SERVICE_NAME=quill-rag
ENV OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=true
EXPOSE 8000
CMD ["opentelemetry-instrument", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
