package gpgunlock

import (
	"reflect"
	"strings"
	"testing"
)

func TestParseKeysFile(t *testing.T) {
	cases := []struct {
		name    string
		content string
		want    []string
	}{
		{
			name:    "empty file yields no keys",
			content: "",
			want:    nil,
		},
		{
			name:    "single key per line",
			content: "AAAA1111BBBB2222\n",
			want:    []string{"AAAA1111BBBB2222"},
		},
		{
			name:    "comments and blank lines are skipped",
			content: "# nix-generated key list\n\n  CFD6C7FED46F6870BE13CE87D39580F75062BEFC  \n\nB658D64F6FDBCFD1EBA53509A1D4ECB0118566C8\n# end\n",
			want:    []string{"CFD6C7FED46F6870BE13CE87D39580F75062BEFC", "B658D64F6FDBCFD1EBA53509A1D4ECB0118566C8"},
		},
		{
			name:    "hex prefix is stripped",
			content: "0x1234ABCD\n",
			want:    []string{"1234ABCD"},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := ParseKeysFile(tc.content)
			if !reflect.DeepEqual(got, tc.want) {
				t.Fatalf("ParseKeysFile = %v, want %v", got, tc.want)
			}
		})
	}
}

func TestNormalizeSigningKey(t *testing.T) {
	cases := []struct {
		name string
		raw  string
		want string
	}{
		{name: "trims whitespace", raw: "  ABCD1234  ", want: "ABCD1234"},
		{name: "strips 0x prefix", raw: "0xABCD1234", want: "ABCD1234"},
		{name: "strips bare keyid exclamation", raw: "ABCD1234!", want: "ABCD1234"},
		{name: "keeps fingerprint", raw: "CFD6C7FED46F6870BE13CE87D39580F75062BEFC", want: "CFD6C7FED46F6870BE13CE87D39580F75062BEFC"},
		{name: "keeps long keyid", raw: "CFD6C7FED46F6870BE13CE87D39580F75062BEFC", want: "CFD6C7FED46F6870BE13CE87D39580F75062BEFC"},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := NormalizeSigningKey(tc.raw); got != tc.want {
				t.Fatalf("NormalizeSigningKey(%q) = %q, want %q", tc.raw, got, tc.want)
			}
		})
	}
}

func TestUnionKeys(t *testing.T) {
	cases := []struct {
		name  string
		git   string
		extra []string
		want  []string
	}{
		{
			name:  "git key empty keeps only file keys",
			git:   "",
			extra: []string{"AAAA1111BBBB2222", "CCCC3333DDDD4444"},
			want:  []string{"AAAA1111BBBB2222", "CCCC3333DDDD4444"},
		},
		{
			name:  "deduplicates case-insensitively preserving order",
			git:   "AAAA1111BBBB2222!",
			extra: []string{"aaaa1111bbbb2222", "EEEE5555FFFF6666"},
			want:  []string{"AAAA1111BBBB2222", "EEEE5555FFFF6666"},
		},
		{
			name:  "git key comes first",
			git:   "EEEE5555FFFF6666",
			extra: []string{"AAAA1111BBBB2222"},
			want:  []string{"EEEE5555FFFF6666", "AAAA1111BBBB2222"},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := UnionKeys(tc.git, tc.extra)
			if !reflect.DeepEqual(got, tc.want) {
				t.Fatalf("UnionKeys = %v, want %v", got, tc.want)
			}
		})
	}
}

func TestSigningCapable(t *testing.T) {
	cases := []struct {
		name   string
		output string
		want   bool
	}{
		{
			name:   "primary secret key with sign capability",
			output: "sec:-:4096:1:D39580F75062BEFC:1783349514:1941029514::-:::scESC:::+:::23::0:\nfpr:::::::::CFD6C7FED46F6870BE13CE87D39580F75062BEFC:\n",
			want:   true,
		},
		{
			name:   "sign-capable subkey",
			output: "sec:-:4096:1:D39580F75062BEFC:1783349514:1941029514::-:::scESC:::+:::23::0:\nssb:-:4096:1:1234ABCD5678EF90:1783349514:1941029514:::::s:::+:::23:\n",
			want:   true,
		},
		{
			name:   "encryption-only subkey still reports the sign-capable primary",
			output: "sec:-:4096:1:D39580F75062BEFC:1783349514:1941029514::-:::scESC:::+:::23::0:\nssb:-:4096:1:E317BFF449149554:1783349514:1941029514:::::e:::+:::23:\n",
			want:   true,
		},
		{
			name:   "encryption-only secret key is rejected",
			output: "sec:-:4096:1:D39580F75062BEFC:1783349514:1941029514:::::::::e:::+:::23::0:\n",
			want:   false,
		},
		{
			name:   "public key listing without secret rows is rejected",
			output: "pub:-:4096:1:D39580F75062BEFC:1783349514:1941029514::-:::scESC:::+:::23:\nfpr:::::::::CFD6C7FED46F6870BE13CE87D39580F75062BEFC:\n",
			want:   false,
		},
		{
			name:   "empty output is rejected",
			output: "",
			want:   false,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := SigningCapable(tc.output); got != tc.want {
				t.Fatalf("SigningCapable = %v, want %v", got, tc.want)
			}
		})
	}
}

func TestSignArgs(t *testing.T) {
	got := SignArgs("/tmp/x", "ABCD1234EF567890", "/tmp/x/msg.txt", "/tmp/x/msg.sig")
	joined := strings.Join(got, " ")
	if !strings.Contains(joined, "ABCD1234EF567890") {
		t.Fatalf("SignArgs must contain the key, got %v", got)
	}
	if !strings.Contains(joined, "--detach-sign") || !strings.Contains(joined, "--local-user") {
		t.Fatalf("SignArgs must request a detached signature for the key, got %v", got)
	}
}
