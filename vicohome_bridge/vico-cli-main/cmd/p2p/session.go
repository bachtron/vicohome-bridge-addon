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
	sessionDeviceID string
	sessionStream   string
)

var sessionCmd = &cobra.Command{
	Use:   "session",
	Short: "Open a P2P connection and fetch a WebRTC ticket",
	RunE: func(cmd *cobra.Command, args []string) error {
		deviceID := strings.TrimSpace(sessionDeviceID)
		if deviceID == "" {
			return fmt.Errorf("device ID is required")
		}

		stream := strings.ToUpper(strings.TrimSpace(sessionStream))
		if stream == "" {
			stream = "MAIN"
		}

		openResp, err := openP2PConnection(deviceID)
		if err != nil {
			return fmt.Errorf("open P2P connection failed: %w", err)
		}

		ticketResp, err := getWebRTCTicket(deviceID, stream)
		if err != nil {
			return fmt.Errorf("get WebRTC ticket failed: %w", err)
		}

		output := map[string]interface{}{
			"deviceId":     deviceID,
			"stream":       stream,
			"timestamp":    time.Now().UTC().Format(time.RFC3339),
			"openResponse": openResp,
			"ticket":       ticketResp,
		}

		encoder := json.NewEncoder(os.Stdout)
		encoder.SetEscapeHTML(false)
		return encoder.Encode(output)
	},
}

func init() {
	sessionCmd.Flags().StringVar(&sessionDeviceID, "device", "", "Vicohome device ID / serial number")
	sessionCmd.Flags().StringVar(&sessionStream, "stream", "MAIN", "Stream type (MAIN/SUB)")
	sessionCmd.MarkFlagRequired("device") //nolint:errcheck
}
