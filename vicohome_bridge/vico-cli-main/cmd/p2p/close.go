package p2p

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/spf13/cobra"
)

var (
	closeDeviceID  string
	closeSessionID string
)

var closeCmd = &cobra.Command{
	Use:   "close",
	Short: "Close an existing P2P/WebRTC connection",
	RunE: func(cmd *cobra.Command, args []string) error {
		deviceID := strings.TrimSpace(closeDeviceID)
		if deviceID == "" {
			return fmt.Errorf("device ID is required")
		}

		resp, err := closeP2PConnection(deviceID, strings.TrimSpace(closeSessionID))
		if err != nil {
			return fmt.Errorf("close P2P connection failed: %w", err)
		}

		output := map[string]interface{}{
			"deviceId":      deviceID,
			"sessionId":     strings.TrimSpace(closeSessionID),
			"timestamp":     time.Now().UTC().Format(time.RFC3339),
			"closeResponse": resp,
		}

		encoder := json.NewEncoder(os.Stdout)
		encoder.SetEscapeHTML(false)
		return encoder.Encode(output)
	},
}

func init() {
	closeCmd.Flags().StringVar(&closeDeviceID, "device", "", "Vicohome device ID / serial number")
	closeCmd.Flags().StringVar(&closeSessionID, "session", "", "Optional session/connection identifier returned by open")
	closeCmd.MarkFlagRequired("device") //nolint:errcheck
}
