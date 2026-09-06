package main

import (
	"fmt"
	"strings"
	"testing"
)

func TestStripSpace(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want string
	}{
		{name: "plain uuid", in: "d3b07384-d9a0-4d7f-9c93-2f9c1a6b4e21", want: "d3b07384-d9a0-4d7f-9c93-2f9c1a6b4e21"},
		{name: "trailing newline", in: "d3b07384-d9a0-4d7f-9c93-2f9c1a6b4e21\n", want: "d3b07384-d9a0-4d7f-9c93-2f9c1a6b4e21"},
		{name: "surrounding whitespace", in: "  d3b07384\t\n", want: "d3b07384"},
		{name: "all POSIX space classes", in: " \t\n\v\f\r x \t\n\v\f\r", want: "x"},
		{name: "empty", in: "", want: ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := stripSpace(tt.in); got != tt.want {
				t.Errorf("stripSpace(%q) = %q, want %q", tt.in, got, tt.want)
			}
		})
	}
}

func TestDeviceRe(t *testing.T) {
	tests := []struct {
		in   string
		want bool
	}{
		{"phone", true},
		{"my-tablet_2", true},
		{"dev-1", true},
		{"", false},
		{"with space", false},
		{"hüpf", false},
		{"semi;colon", false},
	}
	for _, tt := range tests {
		if got := deviceRe.MatchString(tt.in); got != tt.want {
			t.Errorf("deviceRe.MatchString(%q) = %v, want %v", tt.in, got, tt.want)
		}
	}
}

func TestUUIDRe(t *testing.T) {
	tests := []struct {
		in   string
		want bool
	}{
		{"d3b07384-d9a0-4d7f-9c93-2f9c1a6b4e21", true},
		{"D3B07384-D9A0-4D7F-9C93-2F9C1A6B4E21", true},
		{"d3b07384d9a04d7f9c932f9c1a6b4e21", false},
		{"d3b07384-d9a0-4d7f-9c93-2f9c1a6b4e2", false},
		{"zzz07384-d9a0-4d7f-9c93-2f9c1a6b4e21", false},
		{"", false},
	}
	for _, tt := range tests {
		if got := uuidRe.MatchString(tt.in); got != tt.want {
			t.Errorf("uuidRe.MatchString(%q) = %v, want %v", tt.in, got, tt.want)
		}
	}
}

func TestBuildLink(t *testing.T) {
	const uuid = "d3b07384-d9a0-4d7f-9c93-2f9c1a6b4e21"
	want := "vless://d3b07384-d9a0-4d7f-9c93-2f9c1a6b4e21@tun.glats.org:443" +
		"?encryption=none&security=tls&sni=tun.glats.org&fp=chrome&type=ws" +
		"&host=tun.glats.org&path=/ed59280aa562f4b7eba4519e3c316e24#mact2-link-phone"
	if got := buildLink(uuid, "phone"); got != want {
		t.Errorf("buildLink() =\n  %s\nwant\n  %s", got, want)
	}
}

// TestConfigTemplatePlaceholders pins the substitution order: first %s is
// the UUID, second the WS path (bash printf arg order).
func TestConfigTemplatePlaceholders(t *testing.T) {
	const uuid = "00000000-1111-4222-8333-444444444444"
	out := fmt.Sprintf(configTemplate, uuid, wsPath)
	if !strings.Contains(out, `"uuid": "`+uuid+`"`) {
		t.Error("rendered config does not embed the UUID at the vless outbound")
	}
	if !strings.Contains(out, `"path": "`+wsPath+`"`) {
		t.Error("rendered config does not embed the WS path")
	}
	if got := out[len(out)-1]; got != '\n' {
		t.Errorf("rendered config must end with a newline, got %q", got)
	}
	if strings.Contains(out, "%!") {
		t.Error("rendered config contains a failed placeholder")
	}
}
