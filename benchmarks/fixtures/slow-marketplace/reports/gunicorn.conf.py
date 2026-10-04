# Finance and support use the reports service during office hours; the nightly settlement
# import runs as a management command in a CronJob, not through gunicorn.
bind = "0.0.0.0:8000"
worker_class = "gthread"
workers = 4
threads = 4
timeout = 120
graceful_timeout = 30
keepalive = 5
accesslog = "-"
