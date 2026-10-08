// Package sshrelay controls the user launchd job for the on-demand relay.
//
// launchd owns the single wstunnel child and wstunnel owns reconnect backoff. The
// controller only persists intent and performs bounded launchctl mutations; it
// does not create a second retry loop.
package sshrelay

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	DefaultLabel       = "org.nixos.ssh-relay"
	DefaultCommandPath = "/bin/launchctl"
	DefaultOnTimeout   = 3 * time.Second
	DefaultOffTimeout  = 5 * time.Second
	DefaultStatusLimit = 5 * time.Second
)

var ErrNotLoaded = errors.New("launchd job is not loaded")
var ErrSuperseded = errors.New("sshrelay: operation superseded")

type Config struct {
	StateDir            string
	PlistPath           string
	Label               string
	OnTimeout           time.Duration
	OffTimeout          time.Duration
	StatusTimeout       time.Duration
	CredentialStagePath string
	HeadersPath         string
}

func (c *Controller) ApplyCredentials(ctx context.Context) error {
	return c.credentials(ctx, false)
}

func (c *Controller) RevokeCredentials(ctx context.Context) error {
	return c.credentials(ctx, true)
}

func (c *Controller) StageCredentials(ctx context.Context, sourcePath string) error {
	ctx, cancel := context.WithTimeout(ctx, c.config.OffTimeout)
	defer cancel()
	return c.withLock(ctx, func() error {
		token, err := ReadSopsAuthorizationToken(sourcePath, uint32(os.Getuid()))
		if err != nil {
			return err
		}
		if err := prepareCredentialDirectory(filepath.Dir(c.config.CredentialStagePath), uint32(os.Getuid())); err != nil {
			return err
		}
		return installAuthorizationStage(c.config.CredentialStagePath, token)
	})
}

func prepareCredentialDirectory(path string, owner uint32) error {
	if !filepath.IsAbs(path) || filepath.Clean(path) != path || pathWithin(builtinsStoreDir, path) {
		return errors.New("sshrelay: credential directory must be an absolute clean non-store path")
	}
	missing := []string{}
	for current := path; ; current = filepath.Dir(current) {
		_, err := os.Lstat(current)
		if err == nil {
			if !trustedChain(current, owner) {
				return errors.New("sshrelay: credential directory ancestor is not trusted")
			}
			break
		}
		if !os.IsNotExist(err) || current == string(filepath.Separator) {
			return errors.New("sshrelay: credential directory ancestor cannot be inspected")
		}
		missing = append(missing, current)
	}
	for i := len(missing) - 1; i >= 0; i-- {
		if err := ensureTrustedDirectory(missing[i], owner, 0o700); err != nil {
			return err
		}
	}
	return ensureTrustedDirectory(path, owner, 0o700)
}

func (c *Controller) credentials(ctx context.Context, revoke bool) error {
	ctx, cancel := context.WithTimeout(ctx, c.config.OffTimeout)
	defer cancel()
	return c.withLock(ctx, func() error {
		st, err := c.readState()
		if err != nil {
			return err
		}
		wasEnabled := st.Enabled
		st.Generation++
		if err := c.writeState(st); err != nil {
			return err
		}
		if err := c.bootoutLocked(ctx); err != nil {
			return c.credentialsFail(st, err)
		}
		var token string
		if revoke {
			if err := c.clearHeaders(); err != nil {
				return c.credentialsFail(st, err)
			}
			st.Enabled = false
			st.Generation++
		} else {
			token, err = ReadAuthorizationToken(c.config.CredentialStagePath, uint32(os.Getuid()))
			if err != nil {
				return c.credentialsFail(st, err)
			}
			if err := installHeaders(c.config.HeadersPath, token); err != nil {
				return c.credentialsFail(st, err)
			}
		}
		if err := c.writeState(st); err != nil {
			return c.credentialsFail(st, err)
		}
		if wasEnabled && !revoke {
			if err := c.startLocked(ctx); err != nil {
				return c.credentialsFail(st, err)
			}
		}
		return nil
	})
}

func (c *Controller) bootoutLocked(ctx context.Context) error {
	err := c.launcher.Bootout(ctx, c.service())
	if errors.Is(err, ErrNotLoaded) {
		return nil
	}
	if err != nil {
		return err
	}
	deadline := time.Now().Add(c.config.OffTimeout)
	for time.Now().Before(deadline) {
		_, err := c.launcher.Print(ctx, c.service())
		if errors.Is(err, ErrNotLoaded) {
			return nil
		}
		if err != nil {
			return err
		}
		time.Sleep(10 * time.Millisecond)
	}
	return errors.New("sshrelay: launchd relay did not stop")
}

func (c *Controller) startLocked(ctx context.Context) error {
	if _, err := c.launcher.Print(ctx, c.service()); errors.Is(err, ErrNotLoaded) {
		if err := c.launcher.Bootstrap(ctx, "gui/"+strconv.Itoa(os.Getuid()), c.config.PlistPath); err != nil {
			return err
		}
	} else if err != nil {
		return err
	}
	return c.launcher.Kickstart(ctx, c.service())
}

func (c *Controller) credentialsFail(st state, cause error) error {
	cleanupCtx, cancel := context.WithTimeout(context.Background(), c.config.OffTimeout)
	defer cancel()
	cleanupErr := c.bootoutLocked(cleanupCtx)
	st.Enabled = false
	st.Generation++
	stateErr := c.writeState(st)
	return errors.Join(cause, cleanupErr, stateErr)
}

func (c *Controller) clearHeaders() error {
	if _, err := os.Lstat(c.config.HeadersPath); errors.Is(err, os.ErrNotExist) {
		return nil
	} else if err != nil {
		return err
	}
	parent, err := os.Stat(filepath.Dir(c.config.HeadersPath))
	if err != nil || parent.Mode().Perm() != 0o700 || ownerUID(parent) != uint32(os.Getuid()) {
		return errors.New("sshrelay: live header parent is not a private user directory")
	}
	if err := ValidateHeaderFile(c.config.HeadersPath); err != nil {
		return err
	}
	info, err := os.Lstat(c.config.HeadersPath)
	if err != nil || ownerUID(info) != uint32(os.Getuid()) {
		return errors.New("sshrelay: live headers are not user-owned")
	}
	return os.Remove(c.config.HeadersPath)
}

type Launcher interface {
	Bootstrap(context.Context, string, string) error
	Kickstart(context.Context, string) error
	Bootout(context.Context, string) error
	Print(context.Context, string) (string, error)
}

type Controller struct {
	config   Config
	launcher Launcher
}

type state struct {
	Enabled    bool   `json:"enabled"`
	Generation uint64 `json:"generation"`
}

type Status struct {
	Intent     string
	Registered string
	PID        string
	Relay      string
	SSH        string
}

func (c *Controller) service() string {
	return "gui/" + strconv.Itoa(os.Getuid()) + "/" + c.config.Label
}

func New(config Config, launcher Launcher) (*Controller, error) {
	if launcher == nil {
		return nil, errors.New("sshrelay: nil launcher")
	}
	if config.StateDir == "" || config.PlistPath == "" || config.Label == "" {
		return nil, errors.New("sshrelay: state directory, plist path, and label are required")
	}
	if config.OnTimeout <= 0 {
		config.OnTimeout = DefaultOnTimeout
	}
	if config.OffTimeout <= 0 {
		config.OffTimeout = DefaultOffTimeout
	}
	if config.StatusTimeout <= 0 {
		config.StatusTimeout = DefaultStatusLimit
	}
	return &Controller{config: config, launcher: launcher}, nil
}

func (c *Controller) On(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, c.config.OnTimeout)
	defer cancel()
	var generation uint64
	if err := c.withLock(ctx, func() error {
		st, err := c.readState()
		if err != nil {
			return err
		}
		st.Enabled = true
		st.Generation++
		if err := c.writeState(st); err != nil {
			return err
		}
		generation = st.Generation
		return nil
	}); err != nil {
		return err
	}

	if _, err := c.launcher.Print(ctx, c.service()); err != nil {
		if !errors.Is(err, ErrNotLoaded) {
			return err
		}
		if err := c.currentGenerationCall(ctx, generation, func() error {
			return c.launcher.Bootstrap(ctx, "gui/"+strconv.Itoa(os.Getuid()), c.config.PlistPath)
		}); err != nil {
			return err
		}
	}
	return c.currentGenerationCall(ctx, generation, func() error {
		return c.launcher.Kickstart(ctx, c.service())
	})
}

func (c *Controller) Off(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, c.config.OffTimeout)
	defer cancel()
	return c.withLock(ctx, func() error {
		var stateErr error
		st, err := c.readState()
		if err != nil {
			stateErr = err
		} else {
			st.Enabled = false
			st.Generation++
			if err := c.writeState(st); err != nil {
				stateErr = err
			}
		}
		bootErr := c.launcher.Bootout(ctx, c.service())
		if errors.Is(bootErr, ErrNotLoaded) {
			bootErr = nil
		}
		return errors.Join(stateErr, bootErr)
	})
}

func (c *Controller) Status(ctx context.Context) (Status, error) {
	ctx, cancel := context.WithTimeout(ctx, c.config.StatusTimeout)
	defer cancel()
	status := Status{Intent: "unknown", Registered: "unknown", Relay: "unknown", SSH: "unknown"}
	if err := c.withLock(ctx, func() error {
		st, err := c.readState()
		if err != nil {
			return err
		}
		if st.Enabled {
			status.Intent = "enabled"
		} else {
			status.Intent = "disabled"
		}
		out, err := c.launcher.Print(ctx, c.service())
		if errors.Is(err, ErrNotLoaded) {
			status.Registered = "no"
			status.PID = "unknown"
			return nil
		}
		if err != nil {
			return err
		}
		status.Registered = "yes"
		status.PID = launchdPID(out)
		return nil
	}); err != nil {
		return status, err
	}
	return status, nil
}

func launchdPID(output string) string {
	for _, line := range strings.Split(output, "\n") {
		fields := strings.Fields(line)
		if len(fields) >= 2 && fields[0] == "pid" {
			return fields[len(fields)-1]
		}
	}
	return "unknown"
}

func (c *Controller) withLock(ctx context.Context, fn func() error) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	if err := os.MkdirAll(c.config.StateDir, 0o700); err != nil {
		return err
	}
	lock, err := os.OpenFile(filepath.Join(c.config.StateDir, "state.lock"), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return err
	}
	defer lock.Close()
	for {
		err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
		if err == nil {
			break
		}
		if !errors.Is(err, syscall.EWOULDBLOCK) && !errors.Is(err, syscall.EAGAIN) {
			return err
		}
		timer := time.NewTimer(10 * time.Millisecond)
		select {
		case <-ctx.Done():
			timer.Stop()
			return ctx.Err()
		case <-timer.C:
		}
	}
	defer syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
	if err := ctx.Err(); err != nil {
		return err
	}
	return fn()
}

func (c *Controller) currentGenerationCall(ctx context.Context, generation uint64, fn func() error) error {
	return c.withLock(ctx, func() error {
		st, err := c.readState()
		if err != nil {
			return err
		}
		if !st.Enabled || st.Generation != generation {
			return ErrSuperseded
		}
		return fn()
	})
}

func (c *Controller) statePath() string { return filepath.Join(c.config.StateDir, "state.json") }

func (c *Controller) readState() (state, error) {
	b, err := os.ReadFile(c.statePath())
	if errors.Is(err, os.ErrNotExist) {
		return state{}, nil
	}
	if err != nil {
		return state{}, err
	}
	var st state
	if err := json.Unmarshal(b, &st); err != nil {
		return state{}, fmt.Errorf("sshrelay: invalid state: %w", err)
	}
	return st, nil
}

func (c *Controller) writeState(st state) error {
	b, err := json.Marshal(st)
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(c.config.StateDir, ".state-*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	if err := tmp.Chmod(0o600); err != nil {
		tmp.Close()
		return err
	}
	if _, err := tmp.Write(append(b, '\n')); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpName, c.statePath())
}
