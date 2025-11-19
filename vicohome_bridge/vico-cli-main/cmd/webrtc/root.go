package webrtc

import "github.com/spf13/cobra"

var webrtcCmd = &cobra.Command{
	Use:   "webrtc",
	Short: "Request WebRTC/P2P tickets",
	Long:  `Interact with the Vicohome WebRTC / P2P session APIs.`,
}

func init() {
	webrtcCmd.AddCommand(ticketCmd)
}

// GetWebrtcCmd exposes the root WebRTC command to the main CLI tree.
func GetWebrtcCmd() *cobra.Command {
	return webrtcCmd
}
