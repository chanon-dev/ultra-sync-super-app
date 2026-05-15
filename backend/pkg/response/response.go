package response

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Meta struct {
	RequestID string `json:"request_id"`
	Timestamp string `json:"timestamp"`
	NextCursor string `json:"next_cursor,omitempty"`
	HasMore    *bool  `json:"has_more,omitempty"`
}

type ErrorDetail struct {
	Field string `json:"field"`
	Issue string `json:"issue"`
}

type APIError struct {
	Code    string        `json:"code"`
	Message string        `json:"message"`
	Details []ErrorDetail `json:"details,omitempty"`
}

type Envelope struct {
	Data  any      `json:"data"`
	Meta  Meta     `json:"meta"`
	Error *APIError `json:"error"`
}

func requestID(c *gin.Context) string {
	if id := c.GetHeader("X-Request-ID"); id != "" {
		return id
	}
	return uuid.NewString()
}

func OK(c *gin.Context, data any) {
	c.JSON(http.StatusOK, Envelope{
		Data:  data,
		Meta:  Meta{RequestID: requestID(c), Timestamp: time.Now().UTC().Format(time.RFC3339)},
		Error: nil,
	})
}

func Created(c *gin.Context, data any) {
	c.JSON(http.StatusCreated, Envelope{
		Data:  data,
		Meta:  Meta{RequestID: requestID(c), Timestamp: time.Now().UTC().Format(time.RFC3339)},
		Error: nil,
	})
}

func Paginated(c *gin.Context, data any, nextCursor string, hasMore bool) {
	c.JSON(http.StatusOK, Envelope{
		Data: data,
		Meta: Meta{
			RequestID:  requestID(c),
			Timestamp:  time.Now().UTC().Format(time.RFC3339),
			NextCursor: nextCursor,
			HasMore:    &hasMore,
		},
		Error: nil,
	})
}

func Err(c *gin.Context, status int, code, message string, details ...ErrorDetail) {
	c.JSON(status, Envelope{
		Data: nil,
		Meta: Meta{RequestID: requestID(c), Timestamp: time.Now().UTC().Format(time.RFC3339)},
		Error: &APIError{
			Code:    code,
			Message: message,
			Details: details,
		},
	})
}

func BadRequest(c *gin.Context, code, message string, details ...ErrorDetail) {
	Err(c, http.StatusBadRequest, code, message, details...)
}

func Unauthorized(c *gin.Context) {
	Err(c, http.StatusUnauthorized, "AUTH-001", "unauthorized")
}

func Forbidden(c *gin.Context) {
	Err(c, http.StatusForbidden, "AUTH-002", "forbidden")
}

func Internal(c *gin.Context) {
	Err(c, http.StatusInternalServerError, "SRV-001", "internal server error")
}
