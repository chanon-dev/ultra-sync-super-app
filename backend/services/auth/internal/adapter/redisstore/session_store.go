package redisstore

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/chanon/ultra-sync/services/auth/internal/domain/entity"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

type SessionStore struct {
	rdb *redis.Client
}

func New(rdb *redis.Client) *SessionStore {
	return &SessionStore{rdb: rdb}
}

// Save stores session keyed by refresh token and a reverse-lookup keyed by session ID.
func (s *SessionStore) Save(ctx context.Context, session *entity.Session) error {
	data, err := json.Marshal(session)
	if err != nil {
		return fmt.Errorf("marshal session: %w", err)
	}

	ttl := time.Until(session.ExpiresAt)

	pipe := s.rdb.Pipeline()
	pipe.Set(ctx, tokenKey(session.RefreshToken), data, ttl)
	pipe.Set(ctx, idKey(session.ID), session.RefreshToken, ttl)

	if _, err := pipe.Exec(ctx); err != nil {
		return fmt.Errorf("redis pipeline save session: %w", err)
	}
	return nil
}

func (s *SessionStore) FindByRefreshToken(ctx context.Context, token string) (*entity.Session, error) {
	data, err := s.rdb.Get(ctx, tokenKey(token)).Bytes()
	if err != nil {
		return nil, fmt.Errorf("session not found: %w", err)
	}

	var session entity.Session
	if err := json.Unmarshal(data, &session); err != nil {
		return nil, fmt.Errorf("unmarshal session: %w", err)
	}
	return &session, nil
}

// Revoke deletes both keys so the session can never be reused.
func (s *SessionStore) Revoke(ctx context.Context, sessionID uuid.UUID) error {
	token, err := s.rdb.Get(ctx, idKey(sessionID)).Result()
	if err != nil {
		return nil // already gone — idempotent
	}

	pipe := s.rdb.Pipeline()
	pipe.Del(ctx, tokenKey(token))
	pipe.Del(ctx, idKey(sessionID))

	if _, err := pipe.Exec(ctx); err != nil {
		return fmt.Errorf("redis pipeline revoke session: %w", err)
	}
	return nil
}

func tokenKey(token string) string   { return "session:token:" + token }
func idKey(id uuid.UUID) string      { return "session:id:" + id.String() }
