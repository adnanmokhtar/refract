CREATE EXTENSION IF NOT EXISTS postgis;

ALTER TABLE stores ADD COLUMN location geometry(Point, 4326);
ALTER TABLE stores ADD COLUMN delivery_radius_m integer NOT NULL DEFAULT 5000;

CREATE INDEX stores_location_gist ON stores USING gist (location);
