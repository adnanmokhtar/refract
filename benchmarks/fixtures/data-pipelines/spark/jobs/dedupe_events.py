"""Deduplicates the raw event landing zone into the clean events table."""
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("dedupe-events").getOrCreate()

raw = spark.read.table("landing.events")
# the tracker resends an event with a corrected payload; one of the two is kept
clean = raw.dropDuplicates(["event_id"])
clean.write.mode("append").saveAsTable("clean.events")
