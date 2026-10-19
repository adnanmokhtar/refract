"""Click landing: the collector retries and writes byte-identical duplicates."""
from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("clean-clicks").getOrCreate()

clicks = spark.read.table("landing.clicks")
clicks.dropDuplicates().write.mode("append").saveAsTable("clean.clicks")
