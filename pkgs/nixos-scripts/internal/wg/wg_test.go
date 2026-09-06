package wg

import (
	"strings"
	"testing"
)

const sampleModule = `let
  peers = {
    # --- wg-peer:managed-start ---
    oneplus9 = {
      ip = "10.13.13.2";
      publicKey = "AAA=";
      psk = config.sops.secrets."wireguard/peer_oneplus9_psk";
    };
    mac = {
      ip = "10.13.13.3";
      publicKey = "BBB=";
      psk = null;
    };
    # --- wg-peer:managed-end ---
  };
  serverIP = "10.13.13.1";
`

func TestHasMarkers(t *testing.T) {
	if !HasMarkers(sampleModule) {
		t.Fatal("sample module should have markers")
	}
	if HasMarkers("no markers here") {
		t.Fatal("plain content should not have markers")
	}
}

func TestParsePeers(t *testing.T) {
	peers, err := ParsePeers(sampleModule)
	if err != nil {
		t.Fatalf("ParsePeers: %v", err)
	}
	if len(peers) != 2 {
		t.Fatalf("got %d peers, want 2", len(peers))
	}
	want := []Peer{
		{Name: "oneplus9", IP: "10.13.13.2", PublicKey: "AAA="},
		{Name: "mac", IP: "10.13.13.3", PublicKey: "BBB="},
	}
	for i, w := range want {
		if peers[i] != w {
			t.Fatalf("peer %d = %+v, want %+v", i, peers[i], w)
		}
	}
}

func TestParsePeersMissingMarkers(t *testing.T) {
	if _, err := ParsePeers("nothing"); err == nil {
		t.Fatal("expected error for missing markers")
	}
}

func TestNextIP(t *testing.T) {
	cases := []struct {
		content string
		want    string
		wantErr bool
	}{
		{sampleModule, "10.13.13.4", false}, // last existing is .3
		{"ip = \"10.13.13.1\";", "10.13.13.2", false},
		{"ip = \"192.168.1.50\";", "10.13.13.1", false}, // network filter
		{`ip = "10.13.13.254";`, "", true},              // exhausted
	}
	for _, c := range cases {
		got, err := NextIP(c.content, "10.13.13")
		if c.wantErr {
			if err == nil {
				t.Fatalf("NextIP(%q) = %q, want error", c.content, got)
			}
			continue
		}
		if err != nil {
			t.Fatalf("NextIP(%q): %v", c.content, err)
		}
		if got != c.want {
			t.Fatalf("NextIP(%q) = %q, want %q", c.content, got, c.want)
		}
	}
}

func TestInsertPeerByteFormat(t *testing.T) {
	out, err := InsertPeer(sampleModule, "samsung2", "10.13.13.4", "CCC=")
	if err != nil {
		t.Fatalf("InsertPeer: %v", err)
	}
	wantBlock := "    samsung2 = {\n      ip = \"10.13.13.4\";\n      publicKey = \"CCC=\";\n      psk = null;\n    };\n"
	if !strings.Contains(out, wantBlock) {
		t.Fatalf("inserted block not byte-exact:\n%q", wantBlock)
	}
	// Must land immediately before the end marker line.
	endIdx := strings.Index(out, EndMark)
	blockIdx := strings.Index(out, wantBlock)
	if blockIdx == -1 || endIdx == -1 || blockIdx > endIdx {
		t.Fatal("block must appear before the end marker")
	}
	// Block must still parse.
	peers, err := ParsePeers(out)
	if err != nil || len(peers) != 3 {
		t.Fatalf("post-insert parse: %v, %d peers", err, len(peers))
	}
}

func TestRemovePeer(t *testing.T) {
	out, removed := RemovePeer(sampleModule, "mac")
	if !removed {
		t.Fatal("expected removal")
	}
	if strings.Contains(out, "BBB=") || strings.Contains(out, "mac = {") {
		t.Fatal("mac block should be gone")
	}
	if !strings.Contains(out, "AAA=") {
		t.Fatal("other peers must survive")
	}
	peers, err := ParsePeers(out)
	if err != nil || len(peers) != 1 {
		t.Fatalf("post-remove parse: %v, %d peers", err, len(peers))
	}
	if _, removed := RemovePeer(sampleModule, "ghost"); removed {
		t.Fatal("removing nonexistent peer must be a no-op")
	}
}

func TestUpdatePeerPublicKey(t *testing.T) {
	// Mirrors the retired python3 regex: DOTALL across the comment lines.
	content := `    # thinkpad
    thinkpad = {
      ip = "10.13.13.4";
      publicKey = "OLD=";
      psk = config.sops.secrets."wireguard/peer_thinkpad_psk";
    };`
	out, ok := UpdatePeerPublicKey(content, "thinkpad", "NEW=")
	if !ok {
		t.Fatal("expected replacement")
	}
	if strings.Contains(out, "OLD=") || !strings.Contains(out, `publicKey = "NEW=";`) {
		t.Fatalf("replacement wrong:\n%s", out)
	}
	if _, ok := UpdatePeerPublicKey(content, "ghost", "NEW="); ok {
		t.Fatal("nonexistent peer must not match")
	}
}

func TestParseWGShowHandshakes(t *testing.T) {
	show := `interface: wg0
  public key: SRVPUB=
  listening port: 51820

peer: AAA=
  endpoint: 1.2.3.4:51820
  allowed ips: 10.13.13.2/32
  latest handshake: 1 minute, 2 seconds ago
  transfer: 1.5 MiB received, 3.2 MiB sent

peer: BBB=
  endpoint: 5.6.7.8:51820
  allowed ips: 10.13.13.3/32
`
	hs := ParseWGShowHandshakes(show)
	if hs["AAA="] != "1 minute, 2 seconds" {
		t.Fatalf("AAA handshake = %q", hs["AAA="])
	}
	if _, ok := hs["BBB="]; ok {
		t.Fatal("BBB has no handshake")
	}
}
