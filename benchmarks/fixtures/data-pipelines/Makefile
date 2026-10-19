.PHONY: rebuild-page-views seed-from-prod

# rebuild page views from scratch after a tracker bug (raw.page_views keeps 30 days)
rebuild-page-views:
	dbt run --project-dir analytics --full-refresh --select fct_page_views

# give staging realistic data
seed-from-prod:
	pg_restore --clean --no-owner -d $(STAGING_DATABASE_URL) prod-latest.dump
