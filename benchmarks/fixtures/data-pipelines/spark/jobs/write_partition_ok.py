"""Rewrites one day of the orders lake table in place — Delta replaceWhere scopes the overwrite."""
import sys

from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("write-orders-day").getOrCreate()
day = sys.argv[1]

orders = spark.sql(f"select * from clean.orders where order_date = '{day}'")
(orders.write.format("delta").mode("overwrite")
    .option("replaceWhere", f"order_date = '{day}'")
    .saveAsTable("lake.orders"))
