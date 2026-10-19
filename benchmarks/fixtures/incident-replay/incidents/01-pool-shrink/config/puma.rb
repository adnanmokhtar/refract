# Puma: 2 workers x 16 threads per pod
workers ENV.fetch("WEB_CONCURRENCY", 2)
max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 16)
threads max_threads_count, max_threads_count
preload_app!
