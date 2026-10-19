"""Lands tracker exports; the tracker added two columns in 2026-08 (older files lack them)."""
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("land-events").getOrCreate()

events = spark.read.parquet("s3://larkmoor-landing/events/")
events.write.mode("append").saveAsTable("landing.events")
