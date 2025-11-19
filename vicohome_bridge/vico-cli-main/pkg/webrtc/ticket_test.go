package webrtc

import (
	"testing"
	"time"
)

func TestExtractTicketValue(t *testing.T) {
	cases := []struct {
		name string
		data map[string]interface{}
		want string
	}{
		{
			name: "top level ticket",
			data: map[string]interface{}{"ticket": "abc"},
			want: "abc",
		},
		{
			name: "ticket info nested",
			data: map[string]interface{}{"ticketInfo": map[string]interface{}{"ticket": "nested"}},
			want: "nested",
		},
		{
			name: "session sdp",
			data: map[string]interface{}{"session": map[string]interface{}{"sdp": "offer"}},
			want: "offer",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := extractTicketValue(tc.data); got != tc.want {
				t.Fatalf("expected %s, got %s", tc.want, got)
			}
		})
	}
}

func TestExtractExpirationValue(t *testing.T) {
	ts := time.Unix(1_700_000_000, 0).UTC().Format(time.RFC3339)
	millisTs := time.Unix(1_700_000_000, 123000000).UTC().Format(time.RFC3339)

	cases := []struct {
		name string
		data map[string]interface{}
		want string
	}{
		{
			name: "seconds epoch",
			data: map[string]interface{}{"expireTime": float64(1_700_000_000)},
			want: ts,
		},
		{
			name: "milliseconds epoch",
			data: map[string]interface{}{"ticketInfo": map[string]interface{}{"expireTime": float64(1_700_000_000_123)}},
			want: millisTs,
		},
		{
			name: "RFC3339",
			data: map[string]interface{}{"expiresAt": "2025-03-04T05:06:07Z"},
			want: "2025-03-04T05:06:07Z",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := extractExpirationValue(tc.data); got != tc.want {
				t.Fatalf("expected %s, got %s", tc.want, got)
			}
		})
	}
}
