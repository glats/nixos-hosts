package gastown

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
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

// Login signs the swarm's agents in to a subscription provider, keeping the grant separate from the user's own login.
func (s *Swarm) Login(provider string) error {
	cmd, err := loginCommand(s.R.Config.OpenCode, s.Town(), provider)
	if err != nil {
		return err
	}
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	return cmd.Run()
}
