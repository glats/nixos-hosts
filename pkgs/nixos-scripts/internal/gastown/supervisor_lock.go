package gastown

import (
	"errors"
	"os"
	"path/filepath"
	"syscall"
)

// ErrSupervisorRunning means another supervisor already holds the project.
var ErrSupervisorRunning = errors.New("another supervisor is already running for this project")

func (s *Swarm) lockPath() string { return filepath.Join(s.Dir(), "supervisor.lock") }

// AcquireSupervisor takes the project's exclusive supervisor lock. The kernel
// drops it when the process dies, so a crash or a power loss never leaves a
// stale lock behind. Two supervisors on one project would send every goal twice.
func (s *Swarm) AcquireSupervisor() (func(), error) {
	if err := os.MkdirAll(s.Dir(), 0o700); err != nil {
		return nil, err
	}
	f, err := os.OpenFile(s.lockPath(), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, err
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		_ = f.Close()
		if errors.Is(err, syscall.EWOULDBLOCK) {
			return nil, ErrSupervisorRunning
		}
		return nil, err
	}
	return func() {
		_ = syscall.Flock(int(f.Fd()), syscall.LOCK_UN)
		_ = f.Close()
	}, nil
}
