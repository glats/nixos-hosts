package gastown

import (
	"errors"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

func loginProviders() []string {
	var names []string
	for name, p := range openCodeProviders {
		if p.Env == "" {
			names = append(names, name)
		}
	}
	sort.Strings(names)
	return names
}

func loginCommand(opencode, town, provider string) (*exec.Cmd, error) {
	if opencode == "" {
		return nil, errors.New("GASTOWN_OPENCODE is not set")
	}
	if p, ok := openCodeProviders[provider]; !ok || p.Env != "" {
		return nil, errors.New("login is for providers that use a subscription: " + strings.Join(loginProviders(), ", "))
	}
	home := filepath.Join(town, ".agent-home")
	if err := os.MkdirAll(home, 0o700); err != nil {
		return nil, err
	}
	cmd := exec.Command(opencode, "auth", "login", provider)
	cmd.Env = append(os.Environ(), "HOME="+home)
	return cmd, nil
}

func freePort() (int, error) {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port, nil
}

func loginPortCommand(login *exec.Cmd, port int) *exec.Cmd {
	cmd := exec.Command(login.Path, "service", "set", "port", strconv.Itoa(port))
	cmd.Env = login.Env
	return cmd
}

// Login signs the swarm's agents in to a subscription provider, keeping the grant separate from the user's own login.
func (s *Swarm) Login(provider string) error {
	cmd, err := loginCommand(s.R.Config.OpenCode, s.Town(), provider)
	if err != nil {
		return err
	}
	port, err := freePort()
	if err != nil {
		return err
	}
	if out, err := loginPortCommand(cmd, port).CombinedOutput(); err != nil {
		return errors.New("could not give the agent home its own OpenCode service port: " + strings.TrimSpace(string(out)))
	}
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	return cmd.Run()
}
