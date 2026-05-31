package postgres

import (
	"context"
	"fmt"
	"time"

	"github.com/chanon/ultra-sync/services/chat/internal/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type RoomRepo struct {
	db *pgxpool.Pool
}

func NewRoomRepo(db *pgxpool.Pool) *RoomRepo {
	return &RoomRepo{db: db}
}

func (r *RoomRepo) Create(ctx context.Context, room *domain.ChatRoom) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck

	_, err = tx.Exec(ctx, `
		INSERT INTO chat_rooms (id, name, created_by, created_at)
		VALUES ($1, $2, $3, $4)
	`, room.ID, room.Name, room.CreatedBy, room.CreatedAt)
	if err != nil {
		return fmt.Errorf("insert room: %w", err)
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO chat_room_members (room_id, user_id, joined_at)
		VALUES ($1, $2, $3)
		ON CONFLICT DO NOTHING
	`, room.ID, room.CreatedBy, time.Now())
	if err != nil {
		return fmt.Errorf("insert room member: %w", err)
	}

	return tx.Commit(ctx)
}

func (r *RoomRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.ChatRoom, error) {
	row := r.db.QueryRow(ctx, `
		SELECT id, name, created_by, created_at
		FROM chat_rooms WHERE id = $1
	`, id)

	room := &domain.ChatRoom{}
	if err := row.Scan(&room.ID, &room.Name, &room.CreatedBy, &room.CreatedAt); err != nil {
		return nil, fmt.Errorf("scan room: %w", err)
	}
	return room, nil
}

func (r *RoomRepo) List(ctx context.Context, userID uuid.UUID, limit int, afterID *uuid.UUID) ([]*domain.ChatRoom, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	var (
		rows pgx.Rows
		err  error
	)

	if afterID != nil && *afterID != uuid.Nil {
		rows, err = r.db.Query(ctx, `
			SELECT cr.id, cr.name, cr.created_by, cr.created_at
			FROM chat_rooms cr
			JOIN chat_room_members crm ON cr.id = crm.room_id
			WHERE crm.user_id = $1
			  AND (cr.created_at < (SELECT created_at FROM chat_rooms WHERE id = $3)
			       OR (cr.created_at = (SELECT created_at FROM chat_rooms WHERE id = $3) AND cr.id < $3))
			ORDER BY cr.created_at DESC, cr.id DESC
			LIMIT $2
		`, userID, limit, *afterID)
	} else {
		rows, err = r.db.Query(ctx, `
			SELECT cr.id, cr.name, cr.created_by, cr.created_at
			FROM chat_rooms cr
			JOIN chat_room_members crm ON cr.id = crm.room_id
			WHERE crm.user_id = $1
			ORDER BY cr.created_at DESC, cr.id DESC
			LIMIT $2
		`, userID, limit)
	}
	if err != nil {
		return nil, fmt.Errorf("list rooms: %w", err)
	}
	defer rows.Close()

	var rooms []*domain.ChatRoom
	for rows.Next() {
		room := &domain.ChatRoom{}
		if err := rows.Scan(&room.ID, &room.Name, &room.CreatedBy, &room.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan room row: %w", err)
		}
		rooms = append(rooms, room)
	}
	return rooms, rows.Err()
}

func (r *RoomRepo) AddMember(ctx context.Context, roomID, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO chat_room_members (room_id, user_id, joined_at)
		VALUES ($1, $2, $3)
		ON CONFLICT DO NOTHING
	`, roomID, userID, time.Now())
	if err != nil {
		return fmt.Errorf("add member: %w", err)
	}
	return nil
}

func (r *RoomRepo) IsMember(ctx context.Context, roomID, userID uuid.UUID) (bool, error) {
	var exists bool
	err := r.db.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM chat_room_members
			WHERE room_id = $1 AND user_id = $2
		)
	`, roomID, userID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("check membership: %w", err)
	}
	return exists, nil
}
