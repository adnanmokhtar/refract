CREATE TABLE users (email TEXT NOT NULL UNIQUE);
CREATE UNIQUE INDEX users_slug ON users(slug);
