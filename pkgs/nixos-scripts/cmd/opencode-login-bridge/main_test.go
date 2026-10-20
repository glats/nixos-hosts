package main

import (
	"reflect"
	"testing"
)

const openaiAuthorizeURL = "https://auth.openai.com/api/accounts/authorize?client_id=dynamic_agent_client&agent_name_hint=OpenCode&ext_agent_host_id=urn%3Auuid%3Ac74271fc-a500-48fb-8a72-da5506959f16&response_type=code&redirect_uri=http%3A%2F%2F127.0.0.1%3A35929%2Fauth%2Fcallback&scope=openid+profile+email+offline_access+resource.invoke+chatgpt.tokens.use.direct&resource=https%3A%2F%2Fapi.openai.com%2Fv1&state=YrlHD1N57o_0CqmS8fuApwZkGSKC83VFW2OUhuOZU9k&nonce=mVA46pnZ1gAlOf62hxzPkZedz-TIt2LQl5TMK1_eoaE&code_challenge_method=S256&code_challenge=iuPFwjBvCsPSEWpF7dH063PZnO0jqRZSlXIjqB0dLUQ"

const legacyOpenaiAuthorizeURL = "https://auth.openai.com/oauth/authorize?client_id=app_EMoamEEZ73f0CkXaXp7hrann&redirect_uri=http%3A%2F%2F127.0.0.1%3A1455%2Fauth%2Fcallback&response_type=code"

const claudeAuthorizeURL = "https://claude.ai/oauth/authorize?code=true&client_id=9d1c250a-e61b-44d6-be93-1a1e14f66f20&redirect_uri=http%3A%2F%2F127.0.0.1%3A53692%2Fcallback&response_type=code"

func TestExtractCallbackPort(t *testing.T) {
	cases := []struct {
		name          string
		raw           string
		port          int
		authorizeHost string
		fail          bool
	}{
		{
			name:          "openai dynamic agent authorize url",
			raw:           openaiAuthorizeURL,
			port:          35929,
			authorizeHost: "auth.openai.com",
		},
		{
			name:          "legacy openai authorize url",
			raw:           legacyOpenaiAuthorizeURL,
			port:          1455,
			authorizeHost: "auth.openai.com",
		},
		{
			name:          "claude authorize url",
			raw:           claudeAuthorizeURL,
			port:          53692,
			authorizeHost: "claude.ai",
		},
		{
			name: "missing redirect_uri",
			raw:  "https://auth.openai.com/api/accounts/authorize?client_id=dynamic_agent_client&response_type=code",
			fail: true,
		},
		{
			name: "redirect_uri without port",
			raw:  "https://example.com/authorize?redirect_uri=http%3A%2F%2F127.0.0.1%2Fcallback",
			fail: true,
		},
		{
			name: "not a url",
			raw:  "://not a url",
			fail: true,
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			port, authorizeHost, err := extractCallbackPort(tc.raw)
			if tc.fail {
				if err == nil {
					t.Fatalf("extractCallbackPort(%q) = %d, want error", tc.raw, port)
				}
				return
			}
			if err != nil {
				t.Fatalf("extractCallbackPort(%q) failed: %v", tc.raw, err)
			}
			if port != tc.port {
				t.Errorf("extractCallbackPort(%q) port = %d, want %d", tc.raw, port, tc.port)
			}
			if authorizeHost != tc.authorizeHost {
				t.Errorf("extractCallbackPort(%q) authorizeHost = %q, want %q", tc.raw, authorizeHost, tc.authorizeHost)
			}
		})
	}
}

func TestResolvePortsDefaults(t *testing.T) {
	ports, err := resolvePorts(false, "1455,1457,53692", nil)
	if err != nil {
		t.Fatalf("resolvePorts failed: %v", err)
	}
	want := []callbackPort{
		{port: 1455},
		{port: 1457},
		{port: 53692},
	}
	if !reflect.DeepEqual(ports, want) {
		t.Errorf("resolvePorts defaults = %v, want %v", ports, want)
	}
}

func TestResolvePortsURLReplacesDefaults(t *testing.T) {
	ports, err := resolvePorts(false, "1455,1457,53692", []string{openaiAuthorizeURL})
	if err != nil {
		t.Fatalf("resolvePorts failed: %v", err)
	}
	want := []callbackPort{{port: 35929, authorizeHost: "auth.openai.com"}}
	if !reflect.DeepEqual(ports, want) {
		t.Errorf("resolvePorts url-only = %v, want %v", ports, want)
	}
}

func TestResolvePortsExplicitPlusURL(t *testing.T) {
	ports, err := resolvePorts(true, "53692", []string{openaiAuthorizeURL})
	if err != nil {
		t.Fatalf("resolvePorts failed: %v", err)
	}
	want := []callbackPort{
		{port: 53692},
		{port: 35929, authorizeHost: "auth.openai.com"},
	}
	if !reflect.DeepEqual(ports, want) {
		t.Errorf("resolvePorts explicit + url = %v, want %v", ports, want)
	}
}

func TestResolvePortsMultipleURLs(t *testing.T) {
	ports, err := resolvePorts(false, "1455,1457,53692", []string{openaiAuthorizeURL, claudeAuthorizeURL})
	if err != nil {
		t.Fatalf("resolvePorts failed: %v", err)
	}
	want := []callbackPort{
		{port: 35929, authorizeHost: "auth.openai.com"},
		{port: 53692, authorizeHost: "claude.ai"},
	}
	if !reflect.DeepEqual(ports, want) {
		t.Errorf("resolvePorts multiple urls = %v, want %v", ports, want)
	}
}

func TestResolvePortsURLDuplicateSkipped(t *testing.T) {
	ports, err := resolvePorts(true, "53692", []string{claudeAuthorizeURL})
	if err != nil {
		t.Fatalf("resolvePorts failed: %v", err)
	}
	want := []callbackPort{{port: 53692}}
	if !reflect.DeepEqual(ports, want) {
		t.Errorf("resolvePorts duplicate = %v, want %v", ports, want)
	}
}

func TestResolvePortsNoSource(t *testing.T) {
	if _, err := resolvePorts(false, "", nil); err == nil {
		t.Error("resolvePorts with no ports and no urls should fail")
	}
}

func TestRenderPorts(t *testing.T) {
	got := renderPorts([]callbackPort{
		{port: 35929, authorizeHost: "auth.openai.com"},
		{port: 53692},
	})
	want := ":35929 (auth.openai.com),:53692"
	if got != want {
		t.Errorf("renderPorts = %q, want %q", got, want)
	}
}

func TestParsePorts(t *testing.T) {
	ports, err := parsePorts("1455, 1457,53692,1455,")
	if err != nil {
		t.Fatalf("parsePorts failed: %v", err)
	}
	want := []int{1455, 1457, 53692}
	if !reflect.DeepEqual(ports, want) {
		t.Errorf("parsePorts = %v, want %v", ports, want)
	}
}
