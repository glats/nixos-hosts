package githubclient

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func authorizationSeen(t *testing.T, github, gh string) (api, other string) {
	t.Helper()
	t.Setenv("GITHUB_TOKEN", github)
	t.Setenv("GH_TOKEN", gh)
	var apiHeader, otherHeader string
	apiSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		apiHeader = r.Header.Get("Authorization")
	}))
	defer apiSrv.Close()
	otherSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		otherHeader = r.Header.Get("Authorization")
	}))
	defer otherSrv.Close()
	client := New(apiSrv.URL)
	for _, url := range []string{apiSrv.URL, otherSrv.URL} {
		resp, err := client.Get(url)
		if err != nil {
			t.Fatal(err)
		}
		resp.Body.Close()
	}
	return apiHeader, otherHeader
}

func TestTokenIsSentOnlyToTheAPIHost(t *testing.T) {
	api, other := authorizationSeen(t, "secret", "")
	if api != "Bearer secret" {
		t.Fatalf("api Authorization = %q", api)
	}
	if other != "" {
		t.Fatalf("token leaked to another host: %q", other)
	}
}

func TestGHTokenIsUsedWhenGithubTokenIsUnset(t *testing.T) {
	if api, _ := authorizationSeen(t, "", "fallback"); api != "Bearer fallback" {
		t.Fatalf("api Authorization = %q", api)
	}
}

func TestNoAuthorizationWithoutToken(t *testing.T) {
	if api, other := authorizationSeen(t, "", ""); api != "" || other != "" {
		t.Fatalf("Authorization sent without a token: %q %q", api, other)
	}
}

func TestStatusErrorExplainsRateLimit(t *testing.T) {
	for status, wantHint := range map[int]bool{
		http.StatusForbidden:       true,
		http.StatusTooManyRequests: true,
		http.StatusNotFound:        false,
	} {
		err := StatusError("leaf", &http.Response{StatusCode: status, Status: http.StatusText(status)})
		if err == nil || !strings.HasPrefix(err.Error(), "leaf: GitHub API returned ") {
			t.Fatalf("status %d: err = %v", status, err)
		}
		if got := strings.Contains(err.Error(), "GITHUB_TOKEN"); got != wantHint {
			t.Fatalf("status %d: token hint = %v, want %v (%v)", status, got, wantHint, err)
		}
	}
}

func TestRedirectFromAPIHostDoesNotCarryToken(t *testing.T) {
	t.Setenv("GITHUB_TOKEN", "sentinel")
	t.Setenv("GH_TOKEN", "")
	var otherAuth string
	other := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		otherAuth = r.Header.Get("Authorization")
	}))
	defer other.Close()
	api := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, other.URL+"/asset", http.StatusFound)
	}))
	defer api.Close()
	resp, err := New(api.URL).Get(api.URL)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if otherAuth != "" {
		t.Fatalf("token leaked to redirect target: %q", otherAuth)
	}
}
