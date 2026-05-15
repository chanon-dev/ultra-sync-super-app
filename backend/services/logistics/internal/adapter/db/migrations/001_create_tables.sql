-- Logistics Service: Initial Schema
-- Requires: PostGIS extension

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Shipments
CREATE TABLE IF NOT EXISTS shipments (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    order_no    VARCHAR(50)     NOT NULL UNIQUE,
    sender_id   UUID            NOT NULL,
    driver_id   UUID,
    status      VARCHAR(20)     NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending','assigned','picked_up','shipping','delivered','cancelled')),
    pickup_geo  GEOMETRY(POINT, 4326) NOT NULL,
    dropoff_geo GEOMETRY(POINT, 4326) NOT NULL,
    price       DECIMAL(20, 4)  NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shipments_sender_id   ON shipments (sender_id);
CREATE INDEX IF NOT EXISTS idx_shipments_driver_id   ON shipments (driver_id) WHERE driver_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_shipments_status      ON shipments (status);
CREATE INDEX IF NOT EXISTS idx_shipments_order_no    ON shipments (order_no);
CREATE INDEX IF NOT EXISTS idx_shipments_pagination  ON shipments (created_at DESC, id);
CREATE INDEX IF NOT EXISTS idx_shipments_pickup_geo  ON shipments USING GIST (pickup_geo);
CREATE INDEX IF NOT EXISTS idx_shipments_dropoff_geo ON shipments USING GIST (dropoff_geo);

-- ShipmentLogs (partitioned by month for performance)
CREATE TABLE IF NOT EXISTS shipment_logs (
    id          BIGSERIAL,
    shipment_id UUID            NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
    status      VARCHAR(20)     NOT NULL,
    current_geo GEOMETRY(POINT, 4326),
    speed_kmh   DOUBLE PRECISION NOT NULL DEFAULT 0,
    metadata    JSONB,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- Create initial partitions (add monthly via cron or migration)
CREATE TABLE IF NOT EXISTS shipment_logs_2026_05
    PARTITION OF shipment_logs
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

CREATE TABLE IF NOT EXISTS shipment_logs_2026_06
    PARTITION OF shipment_logs
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

CREATE INDEX IF NOT EXISTS idx_shipment_logs_shipment_id ON shipment_logs (shipment_id);
CREATE INDEX IF NOT EXISTS idx_shipment_logs_created_at  ON shipment_logs (created_at DESC);
