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
	uc        *usecase.ShipmentUseCase
	driverUC  *usecase.DriverUseCase
	hub       *TrackingHub
}

func New(uc *usecase.ShipmentUseCase, driverUC *usecase.DriverUseCase) *Handler {
	return &Handler{uc: uc, driverUC: driverUC, hub: newTrackingHub()}
}

func (h *Handler) Register(r gin.IRouter) {
	v1 := r.Group("/api/v1")

	// Shipments
	v1.POST("/shipments", h.createShipment)
	v1.GET("/shipments", h.listShipments)
	v1.GET("/shipments/:id", h.getShipment)
	v1.PATCH("/shipments/:id/status", h.updateStatus)
	v1.POST("/shipments/:id/cancel", h.cancelShipment)
	v1.GET("/shipments/:id/route", h.getRoute)
	v1.GET("/shipments/:id/track", h.trackShipment)

	// Driver location (existing)
	v1.POST("/drivers/location", h.updateDriverLocation)

	// Driver management (new)
	v1.POST("/drivers/register", h.registerDriver)
	v1.GET("/drivers", h.listDrivers)
	v1.GET("/drivers/:id", h.getDriver)
	v1.PATCH("/drivers/:id/status", h.updateDriverStatus)
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
		SenderID:       senderID,
		PickupGeo:      entity.GeoPoint{Latitude: req.PickupLat, Longitude: req.PickupLng},
		DropoffGeo:     entity.GeoPoint{Latitude: req.DropoffLat, Longitude: req.DropoffLng},
		IdempotencyKey: c.GetHeader("X-Idempotency-Key"),
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
		response.BadRequest(c, "LOG-400", err.Error())
		return
	}

	response.OK(c, gin.H{"shipment_id": id, "status": req.Status})
}

// POST /api/v1/shipments/:id/cancel
func (h *Handler) cancelShipment(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "VAL-001", "invalid shipment id")
		return
	}

	requesterID, ok := userIDFromHeader(c)
	if !ok {
		response.Unauthorized(c)
		return
	}

	if err := h.uc.CancelShipment(c.Request.Context(), id, requesterID); err != nil {
		response.BadRequest(c, "LOG-400", err.Error())
		return
	}

	response.OK(c, gin.H{"shipment_id": id, "status": "cancelled"})
}

// GET /api/v1/shipments/:id/route
func (h *Handler) getRoute(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "VAL-001", "invalid shipment id")
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "100"))
	afterID, _ := strconv.ParseInt(c.DefaultQuery("after", "0"), 10, 64)

	logs, lastID, err := h.uc.GetRoute(c.Request.Context(), id, limit, afterID)
	if err != nil {
		response.Internal(c)
		return
	}

	items := make([]map[string]any, 0, len(logs))
	for _, l := range logs {
		items = append(items, map[string]any{
			"id":         l.ID,
			"lat":        l.CurrentGeo.Latitude,
			"lng":        l.CurrentGeo.Longitude,
			"speed_kmh":  l.SpeedKmH,
			"status":     l.Status,
			"created_at": l.CreatedAt,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"data": items,
		"meta": gin.H{
			"last_id":  lastID,
			"has_more": len(logs) == limit,
		},
	})
}

// POST /api/v1/drivers/location
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

	h.hub.Broadcast(shipmentID, geo, driverID, req.SpeedKmH)
	response.OK(c, gin.H{"ok": true})
}

// GET /api/v1/shipments/:id/track
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

// POST /api/v1/drivers/register
func (h *Handler) registerDriver(c *gin.Context) {
	userID, ok := userIDFromHeader(c)
	if !ok {
		response.Unauthorized(c)
		return
	}

	var req struct {
		Name         string `json:"name"          binding:"required"`
		PhoneNumber  string `json:"phone_number"`
		VehicleType  string `json:"vehicle_type"  binding:"required,oneof=motorcycle car truck"`
		LicensePlate string `json:"license_plate" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "VAL-001", err.Error())
		return
	}

	d, err := h.driverUC.RegisterDriver(c.Request.Context(), usecase.RegisterDriverInput{
		UserID:       userID,
		Name:         req.Name,
		PhoneNumber:  req.PhoneNumber,
		VehicleType:  req.VehicleType,
		LicensePlate: req.LicensePlate,
	})
	if err != nil {
		response.BadRequest(c, "LOG-400", err.Error())
		return
	}

	response.Created(c, driverJSON(d))
}

// GET /api/v1/drivers
func (h *Handler) listDrivers(c *gin.Context) {
	status := c.Query("status")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	after := c.Query("after")

	drivers, nextCursor, err := h.driverUC.ListDrivers(c.Request.Context(), status, limit, after)
	if err != nil {
		response.Internal(c)
		return
	}

	items := make([]map[string]any, 0, len(drivers))
	for _, d := range drivers {
		items = append(items, driverJSON(d))
	}

	response.Paginated(c, items, nextCursor, nextCursor != "")
}

// GET /api/v1/drivers/:id
func (h *Handler) getDriver(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "VAL-001", "invalid driver id")
		return
	}

	d, err := h.driverUC.GetDriver(c.Request.Context(), id)
	if err != nil {
		response.Err(c, http.StatusNotFound, "LOG-404", "driver not found")
		return
	}

	response.OK(c, driverJSON(d))
}

// PATCH /api/v1/drivers/:id/status
func (h *Handler) updateDriverStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "VAL-001", "invalid driver id")
		return
	}

	var req struct {
		Status string `json:"status" binding:"required,oneof=active inactive"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "VAL-001", err.Error())
		return
	}

	if err := h.driverUC.UpdateDriverStatus(c.Request.Context(), id, entity.DriverStatus(req.Status)); err != nil {
		response.Internal(c)
		return
	}

	response.OK(c, gin.H{"driver_id": id, "status": req.Status})
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

func driverJSON(d *entity.Driver) map[string]any {
	return map[string]any{
		"id":            d.ID,
		"user_id":       d.UserID,
		"name":          d.Name,
		"phone_number":  d.PhoneNumber,
		"vehicle_type":  d.VehicleType,
		"license_plate": d.LicensePlate,
		"status":        d.Status,
		"rating":        d.Rating,
		"created_at":    d.CreatedAt,
	}
}
