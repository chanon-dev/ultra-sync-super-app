package proxy

import (
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
	"time"

	"github.com/gin-gonic/gin"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.uber.org/zap"
)

type ServiceConfig struct {
	Name string
	URL  string
}

type ReverseProxy struct {
	proxies map[string]*httputil.ReverseProxy
	log     *zap.Logger
}

func New(services []ServiceConfig, log *zap.Logger) (*ReverseProxy, error) {
	rp := &ReverseProxy{
		proxies: make(map[string]*httputil.ReverseProxy, len(services)),
		log:     log,
	}

	for _, svc := range services {
		target, err := url.Parse(svc.URL)
		if err != nil {
			return nil, fmt.Errorf("parse %s url %q: %w", svc.Name, svc.URL, err)
		}

		proxy := httputil.NewSingleHostReverseProxy(target)
		proxy.Transport = otelhttp.NewTransport(
			&http.Transport{ResponseHeaderTimeout: 30 * time.Second},
			otelhttp.WithSpanNameFormatter(func(_ string, r *http.Request) string {
				return svc.Name + " " + r.Method + " " + r.URL.Path
			}),
		)
		proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
			log.Error("proxy error", zap.String("service", svc.Name), zap.Error(err))
			w.WriteHeader(http.StatusBadGateway)
		}

		rp.proxies[svc.Name] = proxy
	}

	return rp, nil
}

// Forward returns a Gin handler that forwards the request to the named service.
// It injects X-User-ID and X-User-Role headers from validated JWT claims so
// upstream services can trust the caller's identity without re-validating tokens.
func (rp *ReverseProxy) Forward(serviceName string) gin.HandlerFunc {
	return func(c *gin.Context) {
		proxy, ok := rp.proxies[serviceName]
		if !ok {
			c.JSON(http.StatusBadGateway, gin.H{
				"error": gin.H{"code": "GW-001", "message": "unknown upstream service"},
			})
			return
		}

		rp.log.Debug("forwarding request",
			zap.String("service", serviceName),
			zap.String("path", c.Request.URL.Path),
		)

		if uid, exists := c.Get("user_id"); exists {
			c.Request.Header.Set("X-User-ID", fmt.Sprintf("%v", uid))
		}
		if role, exists := c.Get("role"); exists {
			c.Request.Header.Set("X-User-Role", fmt.Sprintf("%v", role))
		}

		proxy.ServeHTTP(c.Writer, c.Request)
	}
}
