-- hourly: merges the last hour of impressions into the day-partitioned table
MERGE INTO analytics.fct_ad_impressions t
USING staging.impressions_hour s
  ON t.impression_id = s.impression_id
WHEN NOT MATCHED THEN INSERT ROW;
