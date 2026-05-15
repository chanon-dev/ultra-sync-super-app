package rediscache

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/chanon/ultra-sync/services/logistics/internal/domain/entity"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

const locationTTL = 10 * time.Minute

type LocationCache struct {
	rdb *redis.Client
}

func New(rdb *redis.Client) *LocationCache {
	return &LocationCache{rdb: rdb}
}

func (c *LocationCache) SetDriverLocation(ctx context.Context, driverID uuid.UUID, geo entity.GeoPoint) error {
	data, err := json.Marshal(geo)
	if err != nil {
		return fmt.Errorf("marshal geo: %w", err)
	}
	if err := c.rdb.Set(ctx, locationKey(driverID), data, locationTTL).Err(); err != nil {
		return fmt.Errorf("set driver location: %w", err)
	}
	return nil
}

func (c *LocationCache) GetDriverLocation(ctx context.Context, driverID uuid.UUID) (*entity.GeoPoint, error) {
	data, err := c.rdb.Get(ctx, locationKey(driverID)).Bytes()
	if err != nil {
		return nil, fmt.Errorf("get driver location: %w", err)
	}
	var geo entity.GeoPoint
	if err := json.Unmarshal(data, &geo); err != nil {
		return nil, fmt.Errorf("unmarshal geo: %w", err)
	}
	return &geo, nil
}

func locationKey(driverID uuid.UUID) string {
	return "driver:location:" + driverID.String()
}
