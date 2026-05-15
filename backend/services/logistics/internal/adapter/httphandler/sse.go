package httphandler

import (
	"encoding/json"
	"sync"

	"github.com/chanon/ultra-sync/services/logistics/internal/domain/entity"
	"github.com/google/uuid"
)

// TrackingHub fans out driver-location updates to all SSE clients watching a shipment.
type TrackingHub struct {
	mu      sync.RWMutex
	streams map[uuid.UUID][]chan string
}

func newTrackingHub() *TrackingHub {
	return &TrackingHub{streams: make(map[uuid.UUID][]chan string)}
}

// Subscribe registers a new SSE channel for shipmentID and returns the channel
// plus a cancel func the caller must invoke when the connection closes.
func (h *TrackingHub) Subscribe(shipmentID uuid.UUID) (<-chan string, func()) {
	ch := make(chan string, 16)

	h.mu.Lock()
	h.streams[shipmentID] = append(h.streams[shipmentID], ch)
	h.mu.Unlock()

	cancel := func() {
		h.mu.Lock()
		defer h.mu.Unlock()
		clients := h.streams[shipmentID]
		for i, c := range clients {
			if c == ch {
				h.streams[shipmentID] = append(clients[:i], clients[i+1:]...)
				close(ch)
				return
			}
		}
	}
	return ch, cancel
}

// Broadcast sends a location update to every SSE client watching shipmentID.
func (h *TrackingHub) Broadcast(shipmentID uuid.UUID, geo entity.GeoPoint, driverID uuid.UUID, speedKmH float64) {
	payload, _ := json.Marshal(map[string]any{
		"driver_id": driverID.String(),
		"lat":       geo.Latitude,
		"lng":       geo.Longitude,
		"speed_kmh": speedKmH,
	})

	h.mu.RLock()
	clients := h.streams[shipmentID]
	h.mu.RUnlock()

	for _, ch := range clients {
		select {
		case ch <- string(payload):
		default: // drop if consumer is slow
		}
	}
}
