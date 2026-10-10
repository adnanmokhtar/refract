# syntax=docker/dockerfile:1.7
# reports: FastAPI under gunicorn, dependencies by uv. Built reproducibly (see SECURITY.md).
FROM python:3.12-slim
COPY --from=ghcr.io/astral-sh/uv:0.8.22 /uv /usr/local/bin/uv
WORKDIR /srv/reports
RUN apt-get update
RUN apt-get install -y --no-install-recommends build-essential libpq-dev
COPY . .
RUN uv sync --no-dev
RUN <<EOT
uv run python -m compileall -q app
uv run alembic check
EOT
ENV PATH="/srv/reports/.venv/bin:$PATH"
EXPOSE 8000
CMD gunicorn app.main:app -k uvicorn.workers.UvicornWorker -b 0.0.0.0:8000 --graceful-timeout 25
