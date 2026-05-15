package httphandler

import (
	"fmt"
	"net/http"
	"strconv"

	"github.com/chanon/ultra-sync/pkg/response"
	"github.com/chanon/ultra-sync/services/logistics/internal/domain/entity"
	"github.com/chanon/ultra-sync/services/logistics/internal/domain/port"
	"github.com/chanon/ultra-sync/services/logistics/internal/usecase"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Handler struct {
	uc  *usecase.ShipmentUseCase
	hub *TrackingHub
}

func New(uc *usecase.ShipmentUseCase) *Handler {
	return &Handler{uc: uc, hub: newTrackingHub()}
}

func (h *Handler) Register(r gin.IRouter) {
	v1 := r.Group("/api/v1")
	v1.POST("/shipments", h.createShipment)
	v1.GET("/shipments", h.listShipments)
	v1.GET("/shipments/:id", h.getShipment)
	v1.PATCH("/shipments/:id/status", h.updateStatus)
	v1.POST("/drivers/location", h.updateDriverLocation)
	v1.GET("/shipments/:id/track", h.trackShipment)
}

// POST /api/v1/shipments
func (h *Handler) createShipment(c *gin.Context) {
	senderID, ok := userIDFromHeader(c)
	if !ok {
		response.Unauthorized(c)
		return
	}

	var req struct {
		PickupLat  float64 `json:"pickup_lat"  binding:"required"`
		PickupLng  float64 `json:"pickup_lng"  binding:"required"`
		DropoffLat float64 `json:"dropoff_lat" binding:"required"`
		DropoffLng float64 `json:"dropoff_lng" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "VAL-001", err.Error())
		return
	}

	shipment, err := h.uc.CreateShipment(c.Request.Context(), usecase.CreateShipmentInput{
		SenderID:   senderID,
		PickupGeo:  entity.GeoPoint{Latitude: req.PickupLat, Longitude: req.PickupLng},
		DropoffGeo: entity.GeoPoint{Latitude: req.DropoffLat, Longitude: req.DropoffLng},
	})
	if err != nil {
		response.Internal(c)
		return
	}

	response.Created(c, shipmentJSON(shipment))
}

// GET /api/v1/shipments
func (h *Handler) listShipments(c *gin.Context) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	q := port.ListQuery{
		SenderID: c.Query("sender_id"),
		Status:   c.Query("status"),
		After:    c.Query("after"),
		Limit:    limit,
	}

	shipments, nextCursor, err := h.uc.ListShipments(c.Request.Context(), q)
	if err != nil {
		response.Internal(c)
		return
	}

	items := make([]map[string]any, 0, len(shipments))
	for _, s := range shipments {
		items = append(items, shipmentJSON(s))
	}

	response.Paginated(c, items, nextCursor, nextCursor != "")
}

// GET /api/v1/shipments/:id
func (h *Handler) getShipment(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "VAL-001", "invalid shipment id")
		return
	}

	shipment, err := h.uc.GetShipment(c.Request.Context(), id)
	if err != nil {
		response.Err(c, http.StatusNotFound, "LOG-404", "shipment not found")
		return
	}

	response.OK(c, shipmentJSON(shipment))
}

// PATCH /api/v1/shipments/:id/status
func (h *Handler) updateStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "VAL-001", "invalid shipment id")
		return
	}

	var req struct {
		Status string `json:"status" binding:"required,oneof=assigned picked_up shipping delivered cancelled"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "VAL-001", err.Error())
		return
	}

	if err := h.uc.UpdateStatus(c.Request.Context(), id, entity.ShipmentStatus(req.Status)); err != nil {
		response.Internal(c)
		return
	}

	response.OK(c, gin.H{"shipment_id": id, "status": req.Status})
}

// POST /api/v1/drivers/location — driver posts their current GPS position.
func (h *Handler) updateDriverLocation(c *gin.Context) {
	driverID, ok := userIDFromHeader(c)
	if !ok {
		response.Unauthorized(c)
		return
	}

	var req struct {
		ShipmentID string  `json:"shipment_id" binding:"required,uuid"`
		Lat        float64 `json:"lat"`
		Lng        float64 `json:"lng"`
		SpeedKmH   float64 `json:"speed_kmh"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "VAL-001", err.Error())
		return
	}

	shipmentID, _ := uuid.Parse(req.ShipmentID)
	geo := entity.GeoPoint{Latitude: req.Lat, Longitude: req.Lng}

	if err := h.uc.UpdateLocation(c.Request.Context(), shipmentID, driverID, geo, req.SpeedKmH); err != nil {
		response.Internal(c)
		return
	}

	// Fan-out to all SSE clients watching this shipment.
	h.hub.Broadcast(shipmentID, geo, driverID, req.SpeedKmH)

	response.OK(c, gin.H{"ok": true})
}

// GET /api/v1/shipments/:id/track — SSE stream of driver location updates.
func (h *Handler) trackShipment(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "VAL-001", "invalid shipment id")
		return
	}

	ch, cancel := h.hub.Subscribe(id)
	defer cancel()

	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")
	c.Header("Access-Control-Allow-Origin", "*")

	clientGone := c.Request.Context().Done()

	for {
		select {
		case <-clientGone:
			return
		case data, ok := <-ch:
			if !ok {
				return
			}
			fmt.Fprintf(c.Writer, "data: %s\n\n", data)
			c.Writer.Flush()
		}
	}
}

func userIDFromHeader(c *gin.Context) (uuid.UUID, bool) {
	raw := c.GetHeader("X-User-ID")
	if raw == "" {
		return uuid.Nil, false
	}
	id, err := uuid.Parse(raw)
	if err != nil {
		return uuid.Nil, false
	}
	return id, true
}

func shipmentJSON(s *entity.Shipment) map[string]any {
	m := map[string]any{
		"id":          s.ID,
		"order_no":    s.OrderNo,
		"sender_id":   s.SenderID,
		"status":      s.Status,
		"pickup_lat":  s.PickupGeo.Latitude,
		"pickup_lng":  s.PickupGeo.Longitude,
		"dropoff_lat": s.DropoffGeo.Latitude,
		"dropoff_lng": s.DropoffGeo.Longitude,
		"price":       s.Price,
		"created_at":  s.CreatedAt,
		"updated_at":  s.UpdatedAt,
	}
	if s.DriverID != nil {
		m["driver_id"] = s.DriverID
	}
	return m
}
