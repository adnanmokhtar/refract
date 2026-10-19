"""Writes the daily event aggregates, one partition per day."""
import sys

from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("write-daily").getOrCreate()
day = sys.argv[1]

daily = spark.sql(f"select event_date, event_type, count(*) as n from clean.events where event_date = '{day}' group by 1, 2")
daily.write.mode("overwrite").partitionBy("event_date").parquet("s3://larkmoor-lake/events_daily/")
