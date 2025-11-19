package webrtc

import (
	"encoding/json"
	"fmt"
	"os"

	webrtclib "github.com/dydx/vico-cli/pkg/webrtc"
	"github.com/spf13/cobra"
)

var (
	ticketDeviceID string
	ticketFormat   string
)

var ticketCmd = &cobra.Command{
	Use:   "ticket",
	Short: "Fetch a WebRTC/P2P ticket for a device",
	RunE: func(cmd *cobra.Command, args []string) error {
		cmd.SilenceUsage = true

		if ticketDeviceID == "" {
			return emitTicketError(fmt.Errorf("--device/--serial flag is required"))
		}

		if ticketFormat != "json" {
			return emitTicketError(fmt.Errorf("unsupported format '%s' (only json is available)", ticketFormat))
		}

		result, err := webrtclib.RequestTicket(ticketDeviceID)
		if err != nil {
			return emitTicketError(err)
		}

		encoder := json.NewEncoder(os.Stdout)
		encoder.SetEscapeHTML(false)
		if err := encoder.Encode(result); err != nil {
			return err
		}

		return nil
	},
}

func init() {
	ticketCmd.Flags().StringVar(&ticketDeviceID, "device", "", "Device serial number to request a ticket for")
	ticketCmd.Flags().StringVar(&ticketDeviceID, "serial", "", "Alias for --device")
	ticketCmd.Flags().StringVar(&ticketDeviceID, "camera-id", "", "Alias for --device")
	ticketCmd.Flags().StringVar(&ticketFormat, "format", "json", "Output format (json)")
}

func emitTicketError(err error) error {
	payload := map[string]string{
		"error":   "ticket_request_failed",
		"message": err.Error(),
	}

	encoder := json.NewEncoder(os.Stdout)
	encoder.SetEscapeHTML(false)
	_ = encoder.Encode(payload)
	return err
}
