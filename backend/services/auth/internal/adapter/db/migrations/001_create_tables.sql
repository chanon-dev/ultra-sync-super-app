-- Auth Service: Initial Schema

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users
CREATE TABLE IF NOT EXISTS users (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(20)  NOT NULL CHECK (role IN ('user', 'driver', 'admin')),
    status        VARCHAR(20)  NOT NULL DEFAULT 'pending_verify'
                               CHECK (status IN ('pending_verify', 'active', 'suspended')),
    mfa_secret    VARCHAR(255),
    last_login_at TIMESTAMPTZ,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email  ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_status ON users (status);
CREATE INDEX IF NOT EXISTS idx_users_pagination ON users (created_at DESC, id);

-- Sessions (also cached in Redis; Postgres is the durable store)
CREATE TABLE IF NOT EXISTS sessions (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token VARCHAR(512) NOT NULL UNIQUE,
    expires_at    TIMESTAMPTZ  NOT NULL,
    is_revoked    BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id       ON sessions (user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_refresh_token ON sessions (refresh_token);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at    ON sessions (expires_at);
