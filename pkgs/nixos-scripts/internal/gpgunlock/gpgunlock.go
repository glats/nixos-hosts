package gpgunlock

import (
	"path/filepath"
	"strings"
)

// ParseKeysFile reads the Nix-generated key list: one signing key id per
// line, `#` comments and blank lines ignored, optional 0x prefix stripped.
func ParseKeysFile(content string) []string {
	var keys []string
	for _, line := range strings.Split(content, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		keys = append(keys, NormalizeSigningKey(line))
	}
	return keys
}

// NormalizeSigningKey trims a git/gpg key reference and strips the two
// common non-id decorations: the 0x hex prefix and the trailing `!`
// capability marker that git may append to user.signingkey.
func NormalizeSigningKey(raw string) string {
	key := strings.TrimSpace(raw)
	key = strings.TrimPrefix(key, "0x")
	key = strings.TrimSuffix(key, "!")
	return strings.TrimSpace(key)
}

// UnionKeys merges the git-configured signing key with the key list
// supplied by Nix, deduplicating case-insensitively. The git-configured key
// comes first so the current repo's key is unlocked before any others.
func UnionKeys(gitKey string, extra []string) []string {
	var keys []string
	seen := map[string]bool{}
	add := func(raw string) {
		key := NormalizeSigningKey(raw)
		if key == "" {
			return
		}
		id := strings.ToLower(key)
		if seen[id] {
			return
		}
		seen[id] = true
		keys = append(keys, key)
	}
	add(gitKey)
	for _, k := range extra {
		add(k)
	}
	return keys
}

// SigningCapable reports whether the `gpg --with-colons --list-secret-keys`
// output contains a secret-key row (sec or ssb) whose capability field
// allows signing. Public-only listings yield no secret rows and are rejected.
func SigningCapable(colonOutput string) bool {
	for _, line := range strings.Split(colonOutput, "\n") {
		fields := strings.Split(line, ":")
		if len(fields) < 2 {
			continue
		}
		kind := fields[0]
		if kind != "sec" && kind != "ssb" {
			continue
		}
		if len(fields) > 11 && strings.Contains(fields[11], "s") {
			return true
		}
	}
	return false
}

// SignArgs builds the gpg argv used to trigger the passphrase prompt for one
// signing key against a scratch file, so gpg-agent caches it.
func SignArgs(dir, key, msgFile, sigFile string) []string {
	return []string{
		"--yes",
		"--local-user", key,
		"--output", filepath.Clean(sigFile),
		"--detach-sign",
		filepath.Join(dir, msgFile),
	}
}
