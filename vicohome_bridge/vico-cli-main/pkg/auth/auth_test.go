package auth

import (
	"os"
	"testing"
)

func withEnv(key, value string) func() {
	oldValue, had := os.LookupEnv(key)
	if value == "" {
		os.Unsetenv(key)
	} else {
		os.Setenv(key, value)
	}
	return func() {
		if had {
			os.Setenv(key, oldValue)
		} else {
			os.Unsetenv(key)
		}
	}
}

func TestGetAPIBaseURLByRegion(t *testing.T) {
	cleanupRegion := withEnv("VICOHOME_REGION", "")
	defer cleanupRegion()
	cleanupBase := withEnv("VICOHOME_API_BASE", "")
	defer cleanupBase()

	tests := []struct {
		name     string
		region   string
		apiBase  string
		wantBase string
	}{
		{name: "default auto", region: "auto", wantBase: "https://api-us.vicohome.io"},
		{name: "us explicit", region: "us", wantBase: "https://api-us.vicohome.io"},
		{name: "eu region", region: "eu", wantBase: "https://api-eu.vicoo.tech"},
		{name: "api override", region: "us", apiBase: "https://custom.example.com/v1/", wantBase: "https://custom.example.com/v1"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cleanupRegion := withEnv("VICOHOME_REGION", tt.region)
			t.Cleanup(cleanupRegion)
			cleanupBase := withEnv("VICOHOME_API_BASE", tt.apiBase)
			t.Cleanup(cleanupBase)

			got := GetAPIBaseURL()
			if got != tt.wantBase {
				t.Fatalf("GetAPIBaseURL() = %s, want %s", got, tt.wantBase)
			}
		})
	}
}

func TestGetCountryCode(t *testing.T) {
	cleanupRegion := withEnv("VICOHOME_REGION", "")
	defer cleanupRegion()
	cleanupBase := withEnv("VICOHOME_API_BASE", "")
	defer cleanupBase()

	t.Run("eu region", func(t *testing.T) {
		cleanup := withEnv("VICOHOME_REGION", "eu")
		t.Cleanup(cleanup)
		if got := GetCountryCode(); got != "EU" {
			t.Fatalf("GetCountryCode() = %s, want EU", got)
		}
	})

	t.Run("auto defaults to US", func(t *testing.T) {
		cleanupRegion := withEnv("VICOHOME_REGION", "auto")
		t.Cleanup(cleanupRegion)
		cleanupBase := withEnv("VICOHOME_API_BASE", "")
		t.Cleanup(cleanupBase)
		if got := GetCountryCode(); got != "US" {
			t.Fatalf("GetCountryCode() = %s, want US", got)
		}
	})

	t.Run("derive from api base", func(t *testing.T) {
		cleanupRegion := withEnv("VICOHOME_REGION", "")
		t.Cleanup(cleanupRegion)
		cleanupBase := withEnv("VICOHOME_API_BASE", "https://api-eu.vicoo.tech")
		t.Cleanup(cleanupBase)
		if got := GetCountryCode(); got != "EU" {
			t.Fatalf("GetCountryCode() = %s, want EU", got)
		}
	})
}
