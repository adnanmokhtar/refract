-- Application roles. Applied by the platform team when an environment is created; passwords
-- are set out of band from the secrets manager.

CREATE ROLE stallwise_api LOGIN;
CREATE ROLE stallwise_reports LOGIN;
CREATE ROLE stallwise_migrator LOGIN;

GRANT CONNECT ON DATABASE stallwise TO stallwise_api, stallwise_reports, stallwise_migrator;
GRANT USAGE ON SCHEMA public TO stallwise_api, stallwise_reports;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO stallwise_api;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO stallwise_reports;
GRANT INSERT, UPDATE, DELETE ON refunds_refund, refunds_settlementfile TO stallwise_reports;
GRANT ALL ON SCHEMA public TO stallwise_migrator;

-- The reports service runs finance queries through PgBouncer; cap them at the role.
ALTER ROLE stallwise_reports SET statement_timeout = '30s';

-- The API sets its own session limits from its config (api/src/config/database.ts).
ALTER ROLE stallwise_api SET application_name = 'stallwise-api';

-- Migrations may wait on locks, never for long.
ALTER ROLE stallwise_migrator SET lock_timeout = '5s';
