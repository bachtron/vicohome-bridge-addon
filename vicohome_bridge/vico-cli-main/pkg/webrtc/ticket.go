package webrtc

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/dydx/vico-cli/pkg/auth"
)

const (
	defaultTicketEndpoint = "/p2p/startwebrtcsession"
)

// TicketResult represents the normalized WebRTC ticket payload returned to CLI callers.
type TicketResult struct {
	DeviceID  string                 `json:"deviceId"`
	Region    string                 `json:"region"`
	Ticket    string                 `json:"ticket"`
	ExpiresAt string                 `json:"expiresAt,omitempty"`
	Raw       map[string]interface{} `json:"raw,omitempty"`
}

// RequestTicket fetches a WebRTC/P2P ticket for the provided device identifier.
// The function performs authentication, calls the Vicohome API, normalizes the
// response and returns a structure that is ready for JSON serialization.
func RequestTicket(deviceID string) (*TicketResult, error) {
	trimmedID := strings.TrimSpace(deviceID)
	if trimmedID == "" {
		return nil, fmt.Errorf("device serial/ID is required")
	}

	token, err := auth.Authenticate()
	if err != nil {
		return nil, fmt.Errorf("authenticate: %w", err)
	}

	endpoints := resolveTicketEndpoints()
	var lastErr error
	for _, endpoint := range endpoints {
		result, err := requestTicketForEndpoint(trimmedID, token, endpoint)
		if err == nil {
			return result, nil
		}
		lastErr = err
	}

	if lastErr != nil {
		return nil, lastErr
	}
	return nil, fmt.Errorf("failed to fetch ticket")
}

func requestTicketForEndpoint(deviceID, token, endpoint string) (*TicketResult, error) {
	body := map[string]interface{}{
		"deviceId":     deviceID,
		"serialNumber": deviceID,
		"language":     "en",
		"countryNo":    auth.GetCountryCode(),
	}

	payload, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	baseURL := auth.GetAPIBaseURL()
	requestURL := endpoint
	if !strings.HasPrefix(endpoint, "http://") && !strings.HasPrefix(endpoint, "https://") {
		requestURL = baseURL + endpoint
	}
	req, err := http.NewRequest("POST", requestURL, bytes.NewBuffer(payload))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Authorization", token)

	respBody, err := auth.ExecuteWithRetry(req)
	if err != nil {
		return nil, err
	}

	if _, apiErr := auth.ValidateResponse(respBody); apiErr != nil {
		return nil, apiErr
	}

	var response map[string]interface{}
	if err := json.Unmarshal(respBody, &response); err != nil {
		return nil, fmt.Errorf("parse response: %w", err)
	}

	data, _ := response["data"].(map[string]interface{})
	if len(data) == 0 {
		return nil, fmt.Errorf("API response missing ticket payload")
	}

	ticketValue := extractTicketValue(data)
	if ticketValue == "" {
		return nil, fmt.Errorf("API response did not include a ticket")
	}

	result := &TicketResult{
		DeviceID:  deviceID,
		Region:    auth.GetRegionHint(),
		Ticket:    ticketValue,
		ExpiresAt: extractExpirationValue(data),
		Raw:       data,
	}

	return result, nil
}

func resolveTicketEndpoints() []string {
	override := strings.TrimSpace(os.Getenv("VICOHOME_WEBRTC_ENDPOINT"))
	if override != "" {
		return []string{normalizeEndpointPath(override)}
	}
	return []string{defaultTicketEndpoint, "/p2p/startsession"}
}

func normalizeEndpointPath(path string) string {
	if path == "" {
		return defaultTicketEndpoint
	}
	if strings.HasPrefix(path, "http://") || strings.HasPrefix(path, "https://") {
		return path
	}
	if !strings.HasPrefix(path, "/") {
		return "/" + path
	}
	return path
}

func extractTicketValue(data map[string]interface{}) string {
	if val := stringValue(data, "ticket"); val != "" {
		return val
	}
	if val := stringValue(data, "sdp"); val != "" {
		return val
	}
	if val := stringValue(data, "sessionDescription"); val != "" {
		return val
	}
	if info, ok := data["ticketInfo"].(map[string]interface{}); ok {
		if val := stringValue(info, "ticket"); val != "" {
			return val
		}
		if val := stringValue(info, "sdp"); val != "" {
			return val
		}
	}
	if session, ok := data["session"].(map[string]interface{}); ok {
		if val := stringValue(session, "ticket"); val != "" {
			return val
		}
		if val := stringValue(session, "sdp"); val != "" {
			return val
		}
	}
	return ""
}

func extractExpirationValue(data map[string]interface{}) string {
	candidates := []string{"expiresAt", "expireAt", "expireTime", "expiration", "expirationTime"}
	for _, key := range candidates {
		if value, ok := data[key]; ok {
			if ts := normalizeTimestamp(value); ts != "" {
				return ts
			}
		}
	}

	if info, ok := data["ticketInfo"].(map[string]interface{}); ok {
		for _, key := range candidates {
			if value, ok := info[key]; ok {
				if ts := normalizeTimestamp(value); ts != "" {
					return ts
				}
			}
		}
	}

	return ""
}

func stringValue(data map[string]interface{}, key string) string {
	if raw, ok := data[key]; ok {
		if str, ok := raw.(string); ok {
			trimmed := strings.TrimSpace(str)
			if trimmed != "" {
				return trimmed
			}
		}
	}
	return ""
}

func normalizeTimestamp(value interface{}) string {
	switch v := value.(type) {
	case float64:
		if ts, ok := timeFromEpoch(int64(v)); ok {
			return ts.UTC().Format(time.RFC3339)
		}
	case int64:
		if ts, ok := timeFromEpoch(v); ok {
			return ts.UTC().Format(time.RFC3339)
		}
	case string:
		trimmed := strings.TrimSpace(v)
		if trimmed == "" {
			return ""
		}
		if parsed, err := time.Parse(time.RFC3339, trimmed); err == nil {
			return parsed.UTC().Format(time.RFC3339)
		}
		if num, err := parseInt(trimmed); err == nil {
			if ts, ok := timeFromEpoch(num); ok {
				return ts.UTC().Format(time.RFC3339)
			}
		}
	}
	return ""
}

func parseInt(value string) (int64, error) {
	return strconv.ParseInt(value, 10, 64)
}

func timeFromEpoch(value int64) (time.Time, bool) {
	switch {
	case value >= 1e15:
		seconds := value / 1_000_000
		micros := value % 1_000_000
		return time.Unix(seconds, micros*1_000), true
	case value >= 1e12:
		seconds := value / 1_000
		millis := value % 1_000
		return time.Unix(seconds, millis*1_000_000), true
	case value > 0:
		return time.Unix(value, 0), true
	default:
		return time.Time{}, false
	}
}
