package keyringunlock

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"strings"
	"syscall"
	"time"
	"unsafe"
)

type Session struct {
	Connection       string
	TTY              string
	OriginalCommand  string
	PinentryUserData string
	Terminal         bool
}

type Backend interface {
	Locked() (bool, error)
	Password() ([]byte, error)
	Unlock([]byte) error
}

func CurrentSession() Session {
	return Session{
		Connection:       os.Getenv("SSH_CONNECTION"),
		TTY:              os.Getenv("SSH_TTY"),
		OriginalCommand:  os.Getenv("SSH_ORIGINAL_COMMAND"),
		PinentryUserData: os.Getenv("PINENTRY_USER_DATA"),
		Terminal:         isTerminal(os.Stdin) && isTerminal(os.Stdout),
	}
}

func isTerminal(file *os.File) bool {
	_, err := terminalState(file)
	return err == 0
}

func terminalState(file *os.File) (syscall.Termios, syscall.Errno) {
	var state syscall.Termios
	_, _, err := syscall.Syscall(syscall.SYS_IOCTL, file.Fd(), syscall.TCGETS, uintptr(unsafe.Pointer(&state)))
	return state, err
}

func Run(args []string, session Session, backend Backend, output io.Writer) int {
	if len(args) != 0 {
		fmt.Fprintln(output, "Usage: ssh-keyring-unlock\nUnlock the existing login keyring from an interactive SSH terminal.\nEmpty input, cancellation, or failure leaves the SSH login available.")
		if len(args) == 1 && (args[0] == "--help" || args[0] == "-h") {
			return 0
		}
		return 2
	}
	if session.Connection == "" || session.TTY == "" || !session.Terminal || session.OriginalCommand != "" || session.PinentryUserData == "opencode" {
		return 0
	}
	locked, err := backend.Locked()
	if err != nil {
		fmt.Fprintln(output, "Login keyring unavailable; SSH login continues without unlocking GitHub credentials.")
		return 0
	}
	if !locked {
		return 0
	}
	password, err := backend.Password()
	defer clear(password)
	if err != nil || len(password) == 0 {
		fmt.Fprintln(output, "Keyring unlock skipped; SSH login continues.")
		return 0
	}
	if err := backend.Unlock(password); err != nil {
		fmt.Fprintln(output, "Keyring unlock failed; SSH login continues.")
		return 0
	}
	locked, err = backend.Locked()
	if err != nil || locked {
		fmt.Fprintln(output, "Login keyring remains locked or unavailable; SSH login continues.")
		return 0
	}
	fmt.Fprintln(output, "Login keyring unlocked.")
	return 0
}

type SystemBackend struct {
	Input  *os.File
	Output io.Writer
}

func userBus() string {
	return fmt.Sprintf("/run/user/%d/bus", os.Getuid())
}

func (b SystemBackend) Locked() (bool, error) {
	info, err := os.Stat(userBus())
	if err != nil || info.Mode()&os.ModeSocket == 0 {
		return false, errors.New("user bus unavailable")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	command := exec.CommandContext(ctx, "busctl", "--address=unix:path="+userBus(), "--timeout=3s", "get-property",
		"org.freedesktop.secrets", "/org/freedesktop/secrets/aliases/login", "org.freedesktop.Secret.Collection", "Locked")
	output, err := command.Output()
	if err != nil {
		return false, errors.New("cannot inspect login keyring")
	}
	switch strings.TrimSpace(string(output)) {
	case "b true":
		return true, nil
	case "b false":
		return false, nil
	default:
		return false, errors.New("unexpected keyring status")
	}
}

func (b SystemBackend) Password() ([]byte, error) {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	state, err := terminalState(b.Input)
	if err != 0 {
		return nil, errors.New("terminal unavailable")
	}
	defer syscall.Syscall(syscall.SYS_IOCTL, b.Input.Fd(), syscall.TCSETS, uintptr(unsafe.Pointer(&state)))
	ctx, cancel := context.WithTimeout(ctx, 65*time.Second)
	defer cancel()
	command := exec.CommandContext(ctx, "systemd-ask-password", "--timeout=60", "--echo=no", "--emoji=no", "-n", "Unlock login keyring (Enter to skip):")
	command.Cancel = func() error { return command.Process.Signal(os.Interrupt) }
	command.WaitDelay = 2 * time.Second
	command.Stdin = b.Input
	command.Stderr = b.Output
	command.Env = filteredEnvironment("CREDENTIALS_DIRECTORY")
	return command.Output()
}

func (b SystemBackend) Unlock(password []byte) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	command := exec.CommandContext(ctx, "gnome-keyring-daemon", "--unlock")
	command.Stdin = bytes.NewReader(password)
	command.Env = append(filteredEnvironment("DBUS_SESSION_BUS_ADDRESS"), "DBUS_SESSION_BUS_ADDRESS=unix:path="+userBus())
	return command.Run()
}

func filteredEnvironment(name string) []string {
	var result []string
	for _, entry := range os.Environ() {
		if !strings.HasPrefix(entry, name+"=") {
			result = append(result, entry)
		}
	}
	return result
}
