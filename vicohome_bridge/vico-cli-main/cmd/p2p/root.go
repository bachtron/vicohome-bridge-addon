package p2p

import "github.com/spf13/cobra"

var p2pCmd = &cobra.Command{
	Use:   "p2p",
	Short: "Interact with Vicohome P2P/WebRTC endpoints",
	Long:  "Open, close, and fetch tickets for Vicohome P2P/WebRTC live view sessions.",
}

func GetCmd() *cobra.Command {
	return p2pCmd
}

func init() {
	p2pCmd.AddCommand(sessionCmd)
	p2pCmd.AddCommand(closeCmd)
}
