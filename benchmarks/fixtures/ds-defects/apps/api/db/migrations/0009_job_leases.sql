CREATE TABLE job_leases (
  shard integer PRIMARY KEY,
  owner text,
  expires_at timestamptz NOT NULL DEFAULT 'epoch'
);
CREATE TABLE report_leases (
  report_id uuid PRIMARY KEY,
  owner text,
  lease_until timestamptz NOT NULL DEFAULT 'epoch'
);
