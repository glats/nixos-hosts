package sshrelay

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
)

func ReadAuthorizationToken(path string, owner uint32) (string, error) {
	if !trustedChain(filepath.Dir(path), owner) {
		return "", errors.New("sshrelay: authorization path is not trusted")
	}
	file, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NOFOLLOW, 0)
	if err != nil {
		return "", errors.New("sshrelay: authorization file cannot be opened safely")
	}
	defer file.Close()
	if !trustedOpenPath(path, file, owner, 0o600) {
		return "", errors.New("sshrelay: authorization file is not a trusted 0600 file")
	}
	contents, err := io.ReadAll(file)
	if err != nil || !trustedOpenPath(path, file, owner, 0o600) {
		return "", errors.New("sshrelay: authorization file changed while reading")
	}
	return validateAuthorizationToken(strings.TrimSpace(string(contents)))
}

func ReadSopsAuthorizationToken(path string, owner uint32) (string, error) {
	if !filepath.IsAbs(path) || filepath.Clean(path) != path || !trustedSourceLinks(path, owner) {
		return "", errors.New("sshrelay: sops source path is not trusted")
	}
	resolved, err := resolveTrustedSourcePath(path, owner)
	if err != nil {
		return "", errors.New("sshrelay: resolved sops source path is not trusted")
	}
	file, err := os.OpenFile(resolved, os.O_RDONLY|syscall.O_NOFOLLOW, 0)
	if err != nil {
		return "", errors.New("sshrelay: sops source cannot be opened safely")
	}
	defer file.Close()
	if !trustedOpenPath(resolved, file, owner, 0o600) {
		return "", errors.New("sshrelay: sops source is not a trusted 0600 file")
	}
	contents, err := io.ReadAll(file)
	if err != nil || !trustedOpenPath(resolved, file, owner, 0o600) {
		return "", errors.New("sshrelay: sops source changed while reading")
	}
	return validateAuthorizationToken(strings.TrimSpace(string(contents)))
}

func trustedSourceLinks(path string, owner uint32) bool {
	_, err := resolveTrustedSourcePath(path, owner)
	return err == nil
}

func resolveTrustedSourcePath(path string, owner uint32) (string, error) {
	if !filepath.IsAbs(path) || filepath.Clean(path) != path {
		return "", errors.New("source path must be absolute and clean")
	}
	current := string(filepath.Separator)
	if !trustedDirectoryAt(current, owner) {
		return "", errors.New("source root is not trusted")
	}
	pending := sourceComponents(strings.TrimPrefix(path, current))
	for hops := 0; ; hops++ {
		if hops > 40 {
			return "", errors.New("source symlink depth exceeded")
		}
		if len(pending) == 0 {
			return current, nil
		}
		component := pending[0]
		pending = pending[1:]
		switch component {
		case "", ".":
			continue
		case "..":
			if current == string(filepath.Separator) {
				return "", errors.New("source path escaped root")
			}
			if !trustedDirectoryAt(current, owner) {
				return "", errors.New("source parent is not trusted")
			}
			current = filepath.Dir(current)
			continue
		}
		if !trustedDirectoryAt(current, owner) {
			return "", errors.New("source parent is not trusted")
		}
		candidate := filepath.Join(current, component)
		info, err := os.Lstat(candidate)
		if err != nil {
			return "", err
		}
		if info.Mode()&os.ModeSymlink == 0 {
			current = candidate
			if len(pending) == 0 {
				return current, nil
			}
			if !trustedDirectoryAt(current, owner) {
				return "", errors.New("source intermediate path is not trusted")
			}
			continue
		}
		if !rootOwner(ownerUID(info)) {
			return "", errors.New("source symlink is not root-owned")
		}
		target, err := os.Readlink(candidate)
		if err != nil || target == "" {
			return "", errors.New("source symlink target cannot be read")
		}
		if filepath.IsAbs(target) {
			current = string(filepath.Separator)
			pending = append(sourceComponents(strings.TrimPrefix(target, current)), pending...)
		} else {
			pending = append(sourceComponents(target), pending...)
		}
	}
}

func sourceComponents(path string) []string {
	return strings.Split(path, string(filepath.Separator))
}

func trustedDirectoryAt(path string, owner uint32) bool {
	info, err := os.Lstat(path)
	return err == nil && trustedDirectoryPath(info, owner)
}

func installHeaders(path, token string) error {
	if !trustedChain(filepath.Dir(path), uint32(os.Getuid())) {
		return errors.New("sshrelay: header path is not trusted")
	}
	parent, err := os.Stat(filepath.Dir(path))
	if err != nil || parent.Mode().Perm() != 0o700 || ownerUID(parent) != uint32(os.Getuid()) {
		return errors.New("sshrelay: header parent must be a private user directory")
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".headers-")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	if err := tmp.Chmod(0o600); err != nil {
		return err
	}
	if _, err := tmp.WriteString("Authorization: Bearer " + token + "\n"); err != nil {
		return err
	}
	if err := tmp.Sync(); err != nil {
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	if err := os.Rename(tmpPath, path); err != nil {
		return err
	}
	return ValidateHeaderFile(path)
}

func installAuthorizationStage(path, token string) error {
	return installAuthorizationFile(path, token, uint32(os.Getuid()))
}

func installAuthorizationFile(path, token string, owner uint32) error {
	if !trustedChain(filepath.Dir(path), owner) {
		return errors.New("sshrelay: authorization stage path is not trusted")
	}
	parent, err := os.Stat(filepath.Dir(path))
	if err != nil || parent.Mode().Perm() != 0o700 || ownerUID(parent) != owner {
		return errors.New("sshrelay: authorization stage parent must be private")
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".authorization-")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	if err := tmp.Chmod(0o600); err != nil {
		return err
	}
	if _, err := tmp.WriteString(token + "\n"); err != nil {
		return err
	}
	if err := tmp.Sync(); err != nil {
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	if err := os.Rename(tmpPath, path); err != nil {
		return err
	}
	_, err = ReadAuthorizationToken(path, owner)
	return err
}

const relayServerURL = "wss://relay.glats.org:443"

// ClientArgs is the fixed, non-secret argv for the managed Mac publisher.
// Header contents are deliberately never read into argv or the environment.
func ClientArgs(binary, headersFile string, listenerPort uint16) ([]string, error) {
	if !filepath.IsAbs(binary) {
		return nil, errors.New("sshrelay: wstunnel binary path must be absolute")
	}
	if !filepath.IsAbs(headersFile) {
		return nil, errors.New("sshrelay: header file path must be absolute")
	}
	if listenerPort == 0 {
		return nil, errors.New("sshrelay: listener port must be nonzero")
	}
	return []string{
		binary,
		"client",
		"--tls-verify-certificate",
		"--http-headers-file", headersFile,
		"--reverse-tunnel-connection-retry-max-backoff", "60s",
		"--connection-retry-max-backoff", "20s",
		"--log-lvl", "off",
		"-R", fmt.Sprintf("tcp://127.0.0.1:%s:127.0.0.1:22", strconv.Itoa(int(listenerPort))),
		relayServerURL,
	}, nil
}

// SanitizedEnvironment keeps only non-secret platform values. PATH is not
// needed because the child path is absolute; wstunnel option environment
// variables, proxy settings, certificate overrides, and debug/keylog values
// must not influence the managed client.
func SanitizedEnvironment(environment []string) []string {
	allowed := map[string]struct{}{
		"HOME":   {},
		"TMPDIR": {},
	}
	result := make([]string, 0, len(allowed))
	seen := make(map[string]struct{}, len(allowed))
	for _, entry := range environment {
		name, _, ok := strings.Cut(entry, "=")
		if !ok {
			continue
		}
		if _, ok := allowed[name]; !ok {
			continue
		}
		if _, ok := seen[name]; ok {
			continue
		}
		seen[name] = struct{}{}
		result = append(result, entry)
	}
	return result
}

func pathWithin(root, candidate string) bool {
	relative, err := filepath.Rel(root, candidate)
	return err == nil && relative != ".." && !strings.HasPrefix(relative, ".."+string(filepath.Separator))
}

func ValidateHeaderFile(path string) error {
	if !filepath.IsAbs(path) || filepath.Clean(path) != path {
		return errors.New("sshrelay: header file path must be canonical and absolute")
	}
	uid := uint32(os.Getuid())
	if !trustedChain(filepath.Dir(path), uid) {
		return errors.New("sshrelay: header directory chain is not trusted")
	}
	parentInfo, err := os.Stat(filepath.Dir(path))
	if err != nil {
		return fmt.Errorf("sshrelay: header directory: %w", err)
	}
	if parentInfo.Mode().Perm()&0o022 != 0 || ownerUID(parentInfo) != uid {
		return errors.New("sshrelay: header directory must be a non-writable user directory")
	}
	file, err := os.OpenFile(path, os.O_RDONLY|syscall.O_NOFOLLOW, 0)
	if err != nil {
		return errors.New("sshrelay: header file cannot be opened safely")
	}
	defer file.Close()
	if !trustedOpenPath(path, file, uid, 0o600) {
		return errors.New("sshrelay: header file must be a unique user-owned 0600 regular file")
	}
	return nil
}

const builtinsStoreDir = "/nix/store"
