-- Wallet Service: Initial Schema

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Wallets (one per user)
CREATE TABLE IF NOT EXISTS wallets (
    user_id    UUID           PRIMARY KEY,
    balance    DECIMAL(20, 4) NOT NULL DEFAULT 0.0000 CHECK (balance >= 0),
    currency   VARCHAR(10)    NOT NULL DEFAULT 'THB',
    version    INT            NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

-- Transactions (append-only audit log)
CREATE TABLE IF NOT EXISTS transactions (
    id               UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id        UUID           NOT NULL REFERENCES wallets(user_id),
    type             VARCHAR(20)    NOT NULL CHECK (type IN ('topup', 'payment', 'payout')),
    amount           DECIMAL(20, 4) NOT NULL,
    balance_after    DECIMAL(20, 4) NOT NULL,
    reference_id     VARCHAR(255),
    idempotency_key  VARCHAR(255)   NOT NULL UNIQUE,
    created_at       TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_wallet_id       ON transactions (wallet_id);
CREATE INDEX IF NOT EXISTS idx_transactions_type            ON transactions (type);
CREATE INDEX IF NOT EXISTS idx_transactions_idempotency_key ON transactions (idempotency_key);
CREATE INDEX IF NOT EXISTS idx_transactions_pagination      ON transactions (created_at DESC, id);
