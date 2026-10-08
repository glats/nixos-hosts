package sshrelay

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	PolicyService       = "ssh-relay.service"
	PolicyStagePath     = "/run/ssh-relay-staging/authorization"
	PolicyLivePath      = "/run/ssh-relay/restrictions.yaml"
	PolicyRuntimeDir    = "/run/ssh-relay"
	PolicyStateDir      = "/run/ssh-relay/state"
	PolicySystemctlPath = "/run/current-system/sw/bin/systemctl"
)

type policyCommand interface {
	Run(context.Context, ...string) (string, error)
}

type systemctlCommand struct{ path string }

func (c systemctlCommand) Run(ctx context.Context, args ...string) (string, error) {
	output, err := exec.CommandContext(ctx, c.path, args...).CombinedOutput()
	return string(output), err
}

func StageAuthorization(sourcePath string) error {
	if os.Geteuid() != 0 {
		return errors.New("relay-policy stage must run as root")
	}
	return stagePolicyAuthorization(sourcePath, PolicyStagePath, 0)
}

func (t *policyTransaction) Stage(sourcePath string) error {
	if os.Geteuid() != 0 {
		return errors.New("relay-policy stage must run as root")
	}
	return stagePolicyAuthorization(sourcePath, t.stagePath, 0)
}

func stagePolicyAuthorization(sourcePath, destination string, owner uint32) error {
	dir := filepath.Dir(destination)
	if err := ensureTrustedDirectory(dir, owner, 0o700); err != nil {
		return fmt.Errorf("relay-policy: staging directory: %w", err)
	}
	lock, err := os.OpenFile(filepath.Join(dir, ".stage.lock"), os.O_CREATE|os.O_EXCL|os.O_RDWR|syscall.O_NOFOLLOW, 0o600)
	if os.IsExist(err) {
		lock, err = os.OpenFile(filepath.Join(dir, ".stage.lock"), os.O_RDWR|syscall.O_NOFOLLOW, 0)
	}
	if err != nil {
		return err
	}
	defer lock.Close()
	if !trustedOpenPath(filepath.Join(dir, ".stage.lock"), lock, owner, 0o600) {
		return errors.New("relay-policy: staging lock is not trusted")
	}
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		return err
	}
	defer syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
	token, err := ReadSopsAuthorizationToken(sourcePath, owner)
	if err != nil {
		return err
	}
	return installAuthorizationFile(destination, token, owner)
}

type policyTransaction struct {
	command        policyCommand
	service        string
	stagePath      string
	livePath       string
	runtimeDir     string
	stateDir       string
	runtimeOwner   uint32
	stageOwner     uint32
	stateOwner     uint32
	directoryOwner uint32
	policyOwner    uint32
	policyGroup    uint32
	commandLimit   time.Duration
	stopWaitLimit  time.Duration
	cleanupLimit   time.Duration
}

func NewPolicyTransaction() (*policyTransaction, error) {
	if os.Geteuid() != 0 {
		return nil, errors.New("relay-policy must run as root")
	}
	serviceUser, err := user.Lookup("ssh-relay")
	if err != nil {
		return nil, fmt.Errorf("relay-policy: lookup ssh-relay: %w", err)
	}
	uid, err := strconv.ParseUint(serviceUser.Uid, 10, 32)
	if err != nil {
		return nil, errors.New("relay-policy: invalid ssh-relay uid")
	}
	gid, err := strconv.ParseUint(serviceUser.Gid, 10, 32)
	if err != nil {
		return nil, errors.New("relay-policy: invalid ssh-relay gid")
	}
	return &policyTransaction{
		command:        systemctlCommand{path: PolicySystemctlPath},
		service:        PolicyService,
		stagePath:      PolicyStagePath,
		livePath:       PolicyLivePath,
		runtimeDir:     PolicyRuntimeDir,
		stateDir:       PolicyStateDir,
		runtimeOwner:   0,
		stageOwner:     0,
		stateOwner:     0,
		directoryOwner: 0,
		policyOwner:    uint32(uid),
		policyGroup:    uint32(gid),
		commandLimit:   5 * time.Second,
		stopWaitLimit:  5 * time.Second,
		cleanupLimit:   5 * time.Second,
	}, nil
}

func (t *policyTransaction) Apply(ctx context.Context) error {
	return t.withLock(ctx, func(ctx context.Context) error {
		enabled, err := t.wasEnabled(ctx)
		if err != nil {
			return err
		}
		if err := t.maskAndWait(ctx); err != nil {
			return err
		}
		token, err := t.readToken()
		if err != nil {
			return err
		}
		if err := t.installPolicy([]byte(policyForToken(token))); err != nil {
			return err
		}
		if err := t.unmask(ctx); err != nil {
			return t.failStop(err)
		}
		if enabled {
			if err := t.start(ctx); err != nil {
				return t.failStop(err)
			}
		}
		return nil
	})
}

func (t *policyTransaction) Revoke(ctx context.Context) error {
	return t.withLock(ctx, func(ctx context.Context) error {
		if err := t.maskAndWait(ctx); err != nil {
			return err
		}
		if err := t.installPolicy([]byte("restrictions: []\n")); err != nil {
			return err
		}
		return nil
	})
}

func (t *policyTransaction) withLock(ctx context.Context, fn func(context.Context) error) error {
	if err := ensureTrustedDirectory(t.runtimeDir, t.runtimeOwner, 0o755); err != nil {
		return fmt.Errorf("relay-policy: runtime directory: %w", err)
	}
	if err := ensureTrustedDirectory(t.stateDir, t.stateOwner, 0o700); err != nil {
		return fmt.Errorf("relay-policy: state directory: %w", err)
	}
	lock, err := os.OpenFile(filepath.Join(t.stateDir, "transaction.lock"), os.O_CREATE|os.O_EXCL|os.O_RDWR|syscall.O_NOFOLLOW, 0o600)
	if os.IsExist(err) {
		lock, err = os.OpenFile(filepath.Join(t.stateDir, "transaction.lock"), os.O_RDWR|syscall.O_NOFOLLOW, 0)
	}
	if err != nil {
		return err
	}
	defer lock.Close()
	if !trustedOpenPath(filepath.Join(t.stateDir, "transaction.lock"), lock, t.stateOwner, 0o600) {
		return errors.New("relay-policy: transaction lock must be a unique trusted 0600 regular file")
	}
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		return err
	}
	defer syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
	return fn(ctx)
}

func (t *policyTransaction) wasEnabled(ctx context.Context) (bool, error) {
	out, err := t.run(ctx, "is-enabled", t.service)
	status := strings.TrimSpace(out)
	if status == "enabled" {
		return true, nil
	}
	if status == "disabled" || status == "masked" || status == "static" || status == "indirect" || status == "generated" {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("relay-policy: read service state: %w", err)
	}
	return false, errors.New("relay-policy: unknown service enabled state")
}

func (t *policyTransaction) maskAndWait(ctx context.Context) error {
	if _, err := t.run(ctx, "mask", "--runtime", "--now", t.service); err != nil {
		return fmt.Errorf("relay-policy: mask service: %w", err)
	}
	deadline := time.Now().Add(t.stopWaitLimit)
	for {
		status, statusErr := t.run(ctx, "show", "-p", "LoadState", "-p", "ActiveState", "-p", "MainPID", "--value", t.service)
		lines := strings.Split(strings.TrimSuffix(status, "\n"), "\n")
		if statusErr == nil && len(lines) == 3 && lines[0] == "masked" && lines[1] == "inactive" && lines[2] == "0" {
			return nil
		}
		if time.Now().After(deadline) {
			return errors.New("relay-policy: service did not stop with MainPID=0")
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(25 * time.Millisecond):
		}
	}
}

func (t *policyTransaction) failStop(cause error) error {
	ctx, cancel := context.WithTimeout(context.Background(), t.cleanupLimit)
	defer cancel()
	if err := t.maskAndWait(ctx); err != nil {
		return errors.Join(cause, fmt.Errorf("relay-policy: fail-stop verification: %w", err))
	}
	return cause
}

func (t *policyTransaction) unmask(ctx context.Context) error {
	if _, err := t.run(ctx, "unmask", "--runtime", t.service); err != nil {
		return fmt.Errorf("relay-policy: unmask service: %w", err)
	}
	return nil
}

func (t *policyTransaction) start(ctx context.Context) error {
	if _, err := t.run(ctx, "start", t.service); err != nil {
		return fmt.Errorf("relay-policy: start service: %w", err)
	}
	return nil
}

func (t *policyTransaction) run(parent context.Context, args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(parent, t.commandLimit)
	defer cancel()
	return t.command.Run(ctx, args...)
}

func (t *policyTransaction) readToken() (string, error) {
	if !trustedChain(filepath.Dir(t.stagePath), t.stageOwner) {
		return "", errors.New("relay-policy: staged authorization path is not trusted")
	}
	file, err := os.OpenFile(t.stagePath, os.O_RDONLY|syscall.O_NOFOLLOW, 0)
	if err != nil {
		return "", errors.New("relay-policy: staged authorization cannot be opened safely")
	}
	defer file.Close()
	if !trustedOpenPath(t.stagePath, file, t.stageOwner, 0o600) {
		return "", errors.New("relay-policy: staged authorization is not a trusted 0600 regular file")
	}
	contents, err := io.ReadAll(file)
	if err != nil {
		return "", errors.New("relay-policy: staged authorization cannot be read")
	}
	if !trustedOpenPath(t.stagePath, file, t.stageOwner, 0o600) {
		return "", errors.New("relay-policy: staged authorization changed while reading")
	}
	token := strings.TrimSpace(string(contents))
	return validateAuthorizationToken(token)
}

func validateAuthorizationToken(token string) (string, error) {
	if len(token) < 32 || len(token) > 128 {
		return "", errors.New("sshrelay: authorization has invalid length")
	}
	for _, char := range token {
		if !(char >= 'a' && char <= 'z' || char >= 'A' && char <= 'Z' || char >= '0' && char <= '9' || char == '-' || char == '_') {
			return "", errors.New("sshrelay: authorization has invalid characters")
		}
	}
	return token, nil
}

func (t *policyTransaction) installPolicy(policy []byte) error {
	dir := filepath.Dir(t.livePath)
	if err := ensureTrustedDirectory(dir, t.directoryOwner, 0o755); err != nil {
		return fmt.Errorf("relay-policy: live policy parent: %w", err)
	}
	tmp, err := os.OpenFile(filepath.Join(dir, ".ssh-relay-policy-tmp"), os.O_CREATE|os.O_EXCL|os.O_RDWR|syscall.O_NOFOLLOW, 0o600)
	if os.IsExist(err) {
		return errors.New("relay-policy: policy staging file already exists")
	}
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	if err := tmp.Chown(int(t.policyOwner), int(t.policyGroup)); err != nil {
		return err
	}
	if !trustedOpenFile(tmp, t.policyOwner, 0o600) {
		return errors.New("relay-policy: policy staging file is not trusted")
	}
	if _, err := tmp.Write(policy); err != nil {
		return err
	}
	if err := tmp.Sync(); err != nil {
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	if err := os.Rename(tmpPath, t.livePath); err != nil {
		return err
	}
	return nil
}

func policyForToken(token string) string {
	return fmt.Sprintf(`restrictions:
  - name: macm5-ssh-relay
    match:
      - !Authorization "^Bearer %s$"
    allow:
      - !ReverseTunnel
        protocol:
          - Tcp
        port:
          - 22220
        cidr:
          - 127.0.0.1/32
`, token)
}

func ensureTrustedDirectory(path string, owner uint32, mode os.FileMode) error {
	info, err := os.Lstat(path)
	if err == nil {
		if !trustedDirectoryInfo(info, owner, mode) || !trustedChain(filepath.Dir(path), owner) {
			return errors.New("existing directory is not a trusted non-symlink directory")
		}
		return nil
	}
	if !os.IsNotExist(err) || !trustedChain(filepath.Dir(path), owner) {
		return errors.New("directory path is missing or has an untrusted ancestor")
	}
	if err := os.Mkdir(path, mode); err != nil {
		return err
	}
	info, err = os.Lstat(path)
	if err != nil || !trustedDirectoryInfo(info, owner, mode) {
		return errors.New("created directory is not trusted")
	}
	return nil
}

func trustedChain(path string, owner uint32) bool {
	path = filepath.Clean(path)
	if !filepath.IsAbs(path) || pathWithin(builtinsStoreDir, path) {
		return false
	}
	current := string(filepath.Separator)
	for _, part := range strings.Split(strings.TrimPrefix(path, current), string(filepath.Separator)) {
		if part == "" {
			continue
		}
		current = filepath.Join(current, part)
		info, err := os.Lstat(current)
		if err != nil || !trustedDirectoryPath(info, owner) {
			return false
		}
	}
	return true
}

func trustedDirectoryPath(info os.FileInfo, owner uint32) bool {
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return false
	}
	permittedStickyTemp := rootOwner(ownerUID(info)) && info.Mode()&os.ModeSticky != 0 && info.Mode().Perm()&0o022 == 0o022
	return (info.Mode().Perm()&0o022 == 0 || permittedStickyTemp) && (rootOwner(ownerUID(info)) || ownerUID(info) == owner)
}

func rootOwner(uid uint32) bool {
	if uid == 0 {
		return true
	}
	if os.Geteuid() != 0 {
		return false
	}
	b, err := os.ReadFile("/proc/self/uid_map")
	if err != nil {
		return false
	}
	for _, line := range strings.Split(string(b), "\n") {
		fields := strings.Fields(line)
		if len(fields) != 3 || fields[0] != "0" || fields[2] != "1" {
			continue
		}
		host, err := strconv.ParseUint(fields[1], 10, 32)
		if err == nil && host != 0 && uid == 65534 {
			return true
		}
	}
	return false
}

func trustedDirectoryInfo(info os.FileInfo, owner uint32, mode os.FileMode) bool {
	return info.Mode().IsDir() && info.Mode()&os.ModeSymlink == 0 && info.Mode().Perm() == mode && exactOwner(info, owner)
}

func trustedOpenFile(file *os.File, owner uint32, mode os.FileMode) bool {
	info, err := file.Stat()
	if err != nil || !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 || info.Mode().Perm() != mode || !exactOwner(info, owner) {
		return false
	}
	stat, ok := info.Sys().(*syscall.Stat_t)
	return ok && stat.Nlink == 1
}

func trustedOpenPath(path string, file *os.File, owner uint32, mode os.FileMode) bool {
	if !trustedOpenFile(file, owner, mode) {
		return false
	}
	pathInfo, err := os.Lstat(path)
	if err != nil || pathInfo.Mode()&os.ModeSymlink != 0 {
		return false
	}
	fileInfo, err := file.Stat()
	return err == nil && os.SameFile(pathInfo, fileInfo)
}

func exactOwner(info os.FileInfo, uid uint32) bool { return ownerUID(info) == uid }

func ownerUID(info os.FileInfo) uint32 {
	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok {
		return ^uint32(0)
	}
	return uint32(stat.Uid)
}
