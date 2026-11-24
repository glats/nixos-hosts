package lollawatch

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const artwork = "https://lollapaloozacl.com/wp-content/uploads/LOLLACL27-Horarios_1080x1440-VIE12.jpg"

func TestDetectSchedule(t *testing.T) {
	for _, tt := range []struct{ name, html, want string }{
		{"daily lineup", `<img src="https://lollapaloozacl.com/wp-content/uploads/LOTUS-LollaCL2027_LineUp-Diario_3nov-1080x1440-01.jpg">`, ""},
		{"previous schedule", `<img src="https://lollapaloozacl.com/wp-content/uploads/LOLLACL26-Horarios_1080x1440-DOM15.jpg">`, ""},
		{"other site", `<img src="https://example.org/wp-content/uploads/LOLLACL27-Horarios_VIE12.jpg">`, ""},
		{"unpublished markup", `<!-- <img src="` + artwork + `"> -->`, ""},
		{"URL in alt text", `<img alt='example src="` + artwork + `"' src="/lineup.jpg">`, ""},
		{"URL in another element's attribute", `<div title='<img src="` + artwork + `">'></div>`, ""},
		{"quoted tag delimiter before src", `<img alt="a > b" src="` + artwork + `">`, artwork},
		{"festival information", `<img src="/wp-content/uploads/LOLLACL27-Horarios-Apertura-Puertas.jpg">`, ""},
		{"current schedule", `<img loading="lazy" src="/wp-content/uploads/LOLLACL27-Horarios_1080x1440-VIE12.jpg">`, artwork},
	} {
		t.Run(tt.name, func(t *testing.T) {
			if got := detectSchedule([]byte(tt.html)); got != tt.want {
				t.Fatalf("got %q, want %q", got, tt.want)
			}
		})
	}
}

type transportFunc func(*http.Request) (*http.Response, error)

func (f transportFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func TestRunPublishesBeforeTelegramAndRemembersDelivery(t *testing.T) {
	dir := t.TempDir()
	publicPath := filepath.Join(dir, "schedule.json")
	credentials := t.TempDir()
	calls := 0
	client := &http.Client{Transport: transportFunc(func(r *http.Request) (*http.Response, error) {
		body := `<img src="` + artwork + `">`
		switch r.URL.Host {
		case "lollapaloozacl.com":
		case "api.telegram.org":
			calls++
			var payload struct {
				ChatID int64  `json:"chat_id"`
				Text   string `json:"text"`
			}
			if r.Method != http.MethodPost || r.URL.Path != "/bot123:fake-token/sendMessage" ||
				json.NewDecoder(r.Body).Decode(&payload) != nil || payload.ChatID != 456 || !strings.Contains(payload.Text, artwork) {
				t.Fatal("unexpected Telegram request")
			}
			if data, err := os.ReadFile(publicPath); err != nil || !strings.Contains(string(data), artwork) {
				t.Fatalf("schedule missing before Telegram request: %s, %v", data, err)
			}
			if calls == 1 {
				return nil, errors.New("mock transport failure")
			}
			body = `{"ok":true}`
		default:
			t.Fatalf("unexpected request to %s", r.URL.Host)
		}
		return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader(body))}, nil
	})}
	if err := Run(context.Background(), client, dir, ""); err != nil || calls != 0 {
		t.Fatalf("publication without Telegram: calls=%d, err=%v", calls, err)
	}
	for filename, value := range map[string]string{"telegram-token": "123:fake-token", "telegram-chat-id": "456"} {
		if err := os.WriteFile(filepath.Join(credentials, filename), []byte(value), 0600); err != nil {
			t.Fatal(err)
		}
	}
	if err := Run(context.Background(), client, dir, credentials); err == nil || strings.Contains(err.Error(), "fake-token") {
		t.Fatalf("want a credential-free transport failure, got %v", err)
	}
	for range 2 {
		if err := Run(context.Background(), client, dir, credentials); err != nil {
			t.Fatal(err)
		}
	}
	if calls != 2 {
		t.Fatalf("got %d Telegram calls; want one failed attempt and one successful delivery", calls)
	}
}
