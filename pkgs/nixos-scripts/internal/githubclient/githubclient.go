package githubclient

import (
	"fmt"
	"net/http"
	"net/url"
	"os"
	"time"
)

type authTransport struct {
	next  http.RoundTripper
	host  string
	token string
}

func (t authTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	if t.token != "" && req.URL.Host == t.host {
		req = req.Clone(req.Context())
		req.Header.Set("Authorization", "Bearer "+t.token)
	}
	return t.next.RoundTrip(req)
}

func New(apiBase string) *http.Client {
	token := os.Getenv("GITHUB_TOKEN")
	if token == "" {
		token = os.Getenv("GH_TOKEN")
	}
	host := ""
	if u, err := url.Parse(apiBase); err == nil {
		host = u.Host
	}
	return &http.Client{
		Timeout:   time.Minute,
		Transport: authTransport{next: http.DefaultTransport, host: host, token: token},
	}
}

func StatusError(subject string, resp *http.Response) error {
	if resp.StatusCode == http.StatusForbidden || resp.StatusCode == http.StatusTooManyRequests {
		return fmt.Errorf("%s: GitHub API returned %s (rate limit likely exceeded; set GITHUB_TOKEN or GH_TOKEN)", subject, resp.Status)
	}
	return fmt.Errorf("%s: GitHub API returned %s", subject, resp.Status)
}
