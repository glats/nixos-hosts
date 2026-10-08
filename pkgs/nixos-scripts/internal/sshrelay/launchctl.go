package sshrelay

import (
	"context"
	"os/exec"
	"strings"
)

type CommandLauncher struct{ Path string }

func (l CommandLauncher) command(ctx context.Context, args ...string) (string, error) {
	path := l.Path
	if path == "" {
		path = DefaultCommandPath
	}
	cmd := exec.CommandContext(ctx, path, args...)
	out, err := cmd.CombinedOutput()
	if err == nil {
		return string(out), nil
	}
	if exitErr, ok := err.(*exec.ExitError); ok && exitErr.ExitCode() == 3 {
		return string(out), ErrNotLoaded
	}
	text := strings.ToLower(string(out))
	if strings.Contains(text, "could not find service") || strings.Contains(text, "no such process") {
		return string(out), ErrNotLoaded
	}
	return string(out), err
}

func (l CommandLauncher) Bootstrap(ctx context.Context, domain, plist string) error {
	_, err := l.command(ctx, "bootstrap", domain, plist)
	return err
}

func (l CommandLauncher) Kickstart(ctx context.Context, service string) error {
	_, err := l.command(ctx, "kickstart", service)
	return err
}

func (l CommandLauncher) Bootout(ctx context.Context, service string) error {
	_, err := l.command(ctx, "bootout", service)
	return err
}

func (l CommandLauncher) Print(ctx context.Context, service string) (string, error) {
	return l.command(ctx, "print", service)
}
