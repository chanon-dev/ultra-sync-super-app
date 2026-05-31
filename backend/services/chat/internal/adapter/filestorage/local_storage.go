package filestorage

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/google/uuid"
)

// LocalStorage stores uploaded files on the local filesystem and returns a URL.
// Replace with MinIO/S3 adapter in production.
type LocalStorage struct {
	baseDir string
	baseURL string
}

func New(baseDir, baseURL string) (*LocalStorage, error) {
	if err := os.MkdirAll(baseDir, 0750); err != nil {
		return nil, fmt.Errorf("create upload dir: %w", err)
	}
	return &LocalStorage{baseDir: baseDir, baseURL: baseURL}, nil
}

func (s *LocalStorage) Upload(_ context.Context, filename string, data []byte, _ string) (string, error) {
	ext := filepath.Ext(filename)
	name := uuid.NewString() + ext
	path := filepath.Join(s.baseDir, name)

	if err := os.WriteFile(path, data, 0640); err != nil {
		return "", fmt.Errorf("write file: %w", err)
	}
	return fmt.Sprintf("%s/%s", s.baseURL, name), nil
}
