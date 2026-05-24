-- Chat Service: Initial Schema

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Chat Messages
CREATE TABLE IF NOT EXISTS chat_messages (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id     UUID         NOT NULL, -- represents shipment_id or general room ID
    sender_id   UUID         NOT NULL,
    sender_role VARCHAR(20)  NOT NULL CHECK (sender_role IN ('user', 'driver', 'admin')),
    content     TEXT         NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_room_id ON chat_messages (room_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages (room_id, created_at DESC, id);
