package jwt

import (
	"context"
	"crypto/rsa"
	"fmt"
	"time"

	gojwt "github.com/golang-jwt/jwt/v5"
	"github.com/chanon/ultra-sync/services/auth/internal/domain/entity"
	"github.com/chanon/ultra-sync/services/auth/internal/domain/port"
	"github.com/google/uuid"
)

type claims struct {
	UserID string      `json:"uid"`
	Email  string      `json:"email"`
	Role   entity.Role `json:"role"`
	gojwt.RegisteredClaims
}

type Signer struct {
	privateKey *rsa.PrivateKey
	publicKey  *rsa.PublicKey
	issuer     string
	accessTTL  time.Duration
}

func New(privateKey *rsa.PrivateKey, publicKey *rsa.PublicKey, issuer string) *Signer {
	return &Signer{
		privateKey: privateKey,
		publicKey:  publicKey,
		issuer:     issuer,
		accessTTL:  15 * time.Minute,
	}
}

func (s *Signer) Issue(_ context.Context, user *entity.User) (*port.TokenPair, error) {
	now := time.Now()
	expiresAt := now.Add(s.accessTTL)

	c := claims{
		UserID: user.ID.String(),
		Email:  user.Email,
		Role:   user.Role,
		RegisteredClaims: gojwt.RegisteredClaims{
			Issuer:    s.issuer,
			Subject:   user.ID.String(),
			IssuedAt:  gojwt.NewNumericDate(now),
			ExpiresAt: gojwt.NewNumericDate(expiresAt),
		},
	}

	token := gojwt.NewWithClaims(gojwt.SigningMethodRS256, c)
	accessToken, err := token.SignedString(s.privateKey)
	if err != nil {
		return nil, fmt.Errorf("sign access token: %w", err)
	}

	// Refresh token is a random opaque string — no embedded claims.
	refreshToken := uuid.NewString() + uuid.NewString()

	return &port.TokenPair{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    int64(s.accessTTL.Seconds()),
	}, nil
}

func (s *Signer) Verify(_ context.Context, accessToken string) (*entity.User, error) {
	token, err := gojwt.ParseWithClaims(accessToken, &claims{}, func(t *gojwt.Token) (any, error) {
		if _, ok := t.Method.(*gojwt.SigningMethodRSA); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return s.publicKey, nil
	})
	if err != nil {
		return nil, fmt.Errorf("parse token: %w", err)
	}

	c, ok := token.Claims.(*claims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("invalid token claims")
	}

	id, err := uuid.Parse(c.UserID)
	if err != nil {
		return nil, fmt.Errorf("invalid user id in claims: %w", err)
	}

	return &entity.User{ID: id, Email: c.Email, Role: c.Role}, nil
}
