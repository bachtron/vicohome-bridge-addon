package p2p

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/dydx/vico-cli/pkg/auth"
)

const apiBaseURL = "https://api-us.vicohome.io"

func openP2PConnection(deviceID string) (map[string]interface{}, error) {
	payload := map[string]interface{}{
		"deviceId":     deviceID,
		"deviceSn":     deviceID,
		"serialNumber": deviceID,
	}
	return callVicohomeEndpoint("p2p/openp2pconnection", payload)
}

func getWebRTCTicket(deviceID, stream string) (map[string]interface{}, error) {
	payload := map[string]interface{}{
		"deviceId":     deviceID,
		"deviceSn":     deviceID,
		"serialNumber": deviceID,
		"streamType":   strings.ToUpper(stream),
	}
	return callVicohomeEndpoint("webrtc/getwebrtcticket", payload)
}

func closeP2PConnection(deviceID, sessionID string) (map[string]interface{}, error) {
	payload := map[string]interface{}{
		"deviceId":     deviceID,
		"deviceSn":     deviceID,
		"serialNumber": deviceID,
	}

	trimmed := strings.TrimSpace(sessionID)
	if trimmed != "" {
		payload["connectionId"] = trimmed
		payload["sessionId"] = trimmed
	}

	return callVicohomeEndpoint("p2p/closep2pconnection", payload)
}

func callVicohomeEndpoint(path string, payload map[string]interface{}) (map[string]interface{}, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("marshal payload: %w", err)
	}

	token, err := auth.Authenticate()
	if err != nil {
		return nil, fmt.Errorf("authenticate: %w")
	}

	req, err := http.NewRequest("POST", fmt.Sprintf("%s/%s", apiBaseURL, path), bytes.NewBuffer(body))
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Authorization", token)

	respBody, err := auth.ExecuteWithRetry(req)
	if err != nil {
		return nil, err
	}

	var decoded map[string]interface{}
	if err := json.Unmarshal(respBody, &decoded); err != nil {
		return nil, fmt.Errorf("unmarshal response from %s: %w", path, err)
	}

	if code, ok := decoded["code"].(float64); ok && code != 0 {
		msg, _ := decoded["msg"].(string)
		return nil, fmt.Errorf("Vicohome API error (%s): %s (code %.0f)", path, msg, code)
	}

	return decoded, nil
}
