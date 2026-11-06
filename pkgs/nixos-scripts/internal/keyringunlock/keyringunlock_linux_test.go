package keyringunlock

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"testing"
	"time"
	"unsafe"
)

type fakeBackend struct {
	locked      []bool
	statusError error
	password    []byte
	promptError error
	unlockError error
	calls       []string
}

func (f *fakeBackend) Locked() (bool, error) {
	f.calls = append(f.calls, "status")
	if f.statusError != nil {
		return false, f.statusError
	}
	value := f.locked[0]
	if len(f.locked) > 1 {
		f.locked = f.locked[1:]
	}
	return value, nil
}

func (f *fakeBackend) Password() ([]byte, error) {
	f.calls = append(f.calls, "prompt")
	return f.password, f.promptError
}

func (f *fakeBackend) Unlock(password []byte) error {
	f.calls = append(f.calls, "unlock")
	if string(password) != "test passphrase" {
		return errors.New("unexpected password")
	}
	return f.unlockError
}

func TestRun(t *testing.T) {
	ssh := Session{Connection: "client server", TTY: "/dev/pts/1", Terminal: true}
	for _, tt := range []struct {
		name    string
		session Session
		backend fakeBackend
		calls   string
		message string
	}{
		{"local", Session{Terminal: true}, fakeBackend{}, "", ""},
		{"no terminal", Session{Connection: "ssh", TTY: "/dev/pts/1"}, fakeBackend{}, "", ""},
		{"no SSH tty", Session{Connection: "ssh", Terminal: true}, fakeBackend{}, "", ""},
		{"remote command", Session{Connection: "ssh", TTY: "tty", Terminal: true, OriginalCommand: "scp -t target"}, fakeBackend{}, "", ""},
		{"OpenCode", Session{Connection: "ssh", TTY: "tty", Terminal: true, PinentryUserData: "opencode"}, fakeBackend{}, "", ""},
		{"already unlocked", ssh, fakeBackend{locked: []bool{false}}, "status", ""},
		{"unavailable", ssh, fakeBackend{statusError: errors.New("private backend detail")}, "status", "unavailable"},
		{"cancelled", ssh, fakeBackend{locked: []bool{true}, promptError: errors.New("cancelled")}, "status,prompt", "skipped"},
		{"empty password", ssh, fakeBackend{locked: []bool{true}}, "status,prompt", "skipped"},
		{"unlocked", ssh, fakeBackend{locked: []bool{true, false}, password: []byte("test passphrase")}, "status,prompt,unlock,status", "unlocked"},
		{"wrong password", ssh, fakeBackend{locked: []bool{true, true}, password: []byte("test passphrase")}, "status,prompt,unlock,status", "remains locked"},
		{"unlock failed", ssh, fakeBackend{locked: []bool{true}, password: []byte("test passphrase"), unlockError: errors.New("private backend detail")}, "status,prompt,unlock", "failed"},
	} {
		t.Run(tt.name, func(t *testing.T) {
			var output bytes.Buffer
			if code := Run(nil, tt.session, &tt.backend, &output); code != 0 {
				t.Fatalf("login must continue: exit %d", code)
			}
			if got := strings.Join(tt.backend.calls, ","); got != tt.calls {
				t.Fatalf("calls = %q, want %q", got, tt.calls)
			}
			if tt.message == "" && output.Len() != 0 || !strings.Contains(output.String(), tt.message) {
				t.Fatalf("output = %q, want %q", output.String(), tt.message)
			}
			if strings.Contains(output.String(), "test passphrase") || strings.Contains(output.String(), "private backend detail") {
				t.Fatal("sensitive backend information reached output")
			}
			for _, b := range tt.backend.password {
				if b != 0 {
					t.Fatal("password buffer not cleared")
				}
			}
		})
	}
}

func TestArguments(t *testing.T) {
	for _, tt := range []struct {
		args []string
		code int
	}{
		{[]string{"--help"}, 0},
		{[]string{"-h"}, 0},
		{[]string{"--unknown"}, 2},
	} {
		var output bytes.Buffer
		backend := &fakeBackend{}
		if got := Run(tt.args, Session{}, backend, &output); got != tt.code {
			t.Fatalf("Run(%v) = %d, want %d", tt.args, got, tt.code)
		}
		if !strings.Contains(output.String(), "Usage:") || len(backend.calls) != 0 {
			t.Fatal("argument handling must explain usage without touching the keyring")
		}
	}
}

func TestPasswordSubprocess(t *testing.T) {
	if os.Getenv("KEYRING_PASSWORD_TEST") != "1" {
		return
	}
	backend := SystemBackend{Input: os.Stdin, Output: os.Stderr}
	password, err := backend.Password()
	defer clear(password)
	if err == nil && len(password) != 0 {
		t.Fatal("expected skipped input")
	}
	fmt.Println("PASSWORD_SKIPPED")
}

func TestPromptCancellationRestoresTerminalAndShell(t *testing.T) {
	zsh, err := exec.LookPath("zsh")
	if err != nil {
		t.Skip("zsh unavailable")
	}
	if _, err := exec.LookPath("systemd-ask-password"); err != nil {
		t.Skip("systemd-ask-password unavailable")
	}
	for _, tt := range []struct {
		name  string
		input string
	}{
		{"interrupt", "\x03"},
		{"empty", "\n"},
		{"end of input", "\x04"},
	} {
		t.Run(tt.name, func(t *testing.T) {
			master, err := os.OpenFile("/dev/ptmx", os.O_RDWR|syscall.O_NOCTTY, 0)
			if err != nil {
				t.Skipf("PTY unavailable: %v", err)
			}
			defer master.Close()
			var unlocked int32
			if _, _, err := syscall.Syscall(syscall.SYS_IOCTL, master.Fd(), syscall.TIOCSPTLCK, uintptr(unsafe.Pointer(&unlocked))); err != 0 {
				t.Fatal(err)
			}
			var number uint32
			if _, _, err := syscall.Syscall(syscall.SYS_IOCTL, master.Fd(), syscall.TIOCGPTN, uintptr(unsafe.Pointer(&number))); err != 0 {
				t.Fatal(err)
			}
			slave, err := os.OpenFile(fmt.Sprintf("/dev/pts/%d", number), os.O_RDWR|syscall.O_NOCTTY, 0)
			if err != nil {
				t.Fatal(err)
			}
			defer slave.Close()
			before, errno := terminalState(slave)
			if errno != 0 {
				t.Fatal(errno)
			}
			executable, err := os.Executable()
			if err != nil {
				t.Fatal(err)
			}
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			command := exec.CommandContext(ctx, zsh, "-dfi", "-c", `() { setopt localtraps; trap ':' INT; "$KEYRING_TEST_BINARY" -test.run='^TestPasswordSubprocess$' || true; }; print REST_OF_STARTUP`)
			command.Env = append(os.Environ(), "KEYRING_PASSWORD_TEST=1", "KEYRING_TEST_BINARY="+executable)
			command.Stdin, command.Stdout, command.Stderr = slave, slave, slave
			command.SysProcAttr = &syscall.SysProcAttr{Setsid: true, Setctty: true, Ctty: 0}
			if err := command.Start(); err != nil {
				t.Fatal(err)
			}
			prompt := make(chan struct{}, 1)
			finished := make(chan string, 1)
			go func() {
				var output bytes.Buffer
				buffer := make([]byte, 1024)
				for {
					n, err := master.Read(buffer)
					output.Write(buffer[:n])
					if strings.Contains(output.String(), "Enter to skip") {
						select {
						case prompt <- struct{}{}:
						default:
						}
					}
					if err != nil {
						finished <- output.String()
						return
					}
				}
			}()
			select {
			case <-prompt:
				io.WriteString(master, tt.input)
			case <-ctx.Done():
				t.Error("password prompt did not appear")
			}
			waitErr := command.Wait()
			after, errno := terminalState(slave)
			slave.Close()
			output := <-finished
			if waitErr != nil || !strings.Contains(output, "PASSWORD_SKIPPED") || !strings.Contains(output, "REST_OF_STARTUP") {
				t.Fatalf("shell startup interrupted: %v; output %q", waitErr, output)
			}
			if errno != 0 || before.Lflag&(syscall.ECHO|syscall.ICANON) != after.Lflag&(syscall.ECHO|syscall.ICANON) {
				t.Fatal("terminal echo or canonical mode not restored")
			}
		})
	}
}
