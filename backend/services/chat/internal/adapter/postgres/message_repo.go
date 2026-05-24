package postgres

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/chanon/ultra-sync/services/chat/internal/domain"
)

type MessageRepo struct {
	db *pgxpool.Pool
}

func NewMessageRepo(db *pgxpool.Pool) *MessageRepo {
	return &MessageRepo{db: db}
}

func (r *MessageRepo) Save(ctx context.Context, msg *domain.ChatMessage) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO chat_messages (id, room_id, sender_id, sender_role, content, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, msg.ID, msg.RoomID, msg.SenderID, msg.SenderRole, msg.Content, msg.CreatedAt)
	if err != nil {
		return fmt.Errorf("save chat message: %w", err)
	}
	return nil
}

func (r *MessageRepo) GetByRoomID(ctx context.Context, roomID uuid.UUID, limit int, beforeID *uuid.UUID) ([]*domain.ChatMessage, error) {
	var rows pgx.Rows
	var err error

	if beforeID != nil && *beforeID != uuid.Nil {
		rows, err = r.db.Query(ctx, `
			SELECT id, room_id, sender_id, sender_role, content, created_at
			FROM chat_messages
			WHERE room_id = $1 AND (
				created_at < (SELECT created_at FROM chat_messages WHERE id = $3)
				OR (
					created_at = (SELECT created_at FROM chat_messages WHERE id = $3)
					AND id < $3
				)
			)
			ORDER BY created_at DESC, id DESC
			LIMIT $2
		`, roomID, limit, *beforeID)
	} else {
		rows, err = r.db.Query(ctx, `
			SELECT id, room_id, sender_id, sender_role, content, created_at
			FROM chat_messages
			WHERE room_id = $1
			ORDER BY created_at DESC, id DESC
			LIMIT $2
		`, roomID, limit)
	}

	if err != nil {
		return nil, fmt.Errorf("query chat messages: %w", err)
	}
	defer rows.Close()

	var messages []*domain.ChatMessage
	for rows.Next() {
		msg := &domain.ChatMessage{}
		err := rows.Scan(&msg.ID, &msg.RoomID, &msg.SenderID, &msg.SenderRole, &msg.Content, &msg.CreatedAt)
		if err != nil {
			return nil, fmt.Errorf("scan chat message: %w", err)
		}
		messages = append(messages, msg)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}

	// Reverse the list so they are ordered chronologically (oldest first)
	for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
		messages[i], messages[j] = messages[j], messages[i]
	}

	return messages, nil
}
