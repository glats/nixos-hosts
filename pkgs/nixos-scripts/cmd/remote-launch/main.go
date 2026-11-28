package main

import (
	"context"
	"errors"
	"fmt"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/glats/nixos-scripts/internal/nixcache"
	"github.com/glats/nixos-scripts/internal/remotelaunch"
	"github.com/glats/nixos-scripts/internal/sshrelay"
)

const sshPath = "/usr/bin/ssh"

const usage = "usage: remote-launch <host> <port> -- <viewer> [args...]  ({addr} in args is replaced by the reachable address)"

type sshProcess struct {
	cmd  *exec.Cmd
	done chan struct{}
	err  error
}

func (p *sshProcess) Kill() error {
	if p.cmd.Process == nil {
		return nil
	}
	return p.cmd.Process.Kill()
}

func (p *sshProcess) Done() <-chan struct{} { return p.done }

func (p *sshProcess) Err() error { return p.err }

func startForward(argv []string) (remotelaunch.Process, error) {
	cmd := exec.Command(sshPath, argv...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	p := &sshProcess{cmd: cmd, done: make(chan struct{})}
	go func() {
		p.err = cmd.Wait()
		close(p.done)
	}()
	return p, nil
}

func freePort() (int, error) {
	l, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port, nil
}

func runViewer(ctx context.Context, argv []string) (int, error) {
	cmd := exec.CommandContext(ctx, argv[0], argv[1:]...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err := cmd.Run()
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		return exitErr.ExitCode(), nil
	}
	if err != nil {
		return 1, err
	}
	return 0, nil
}

func parseArgs(args []string) (remotelaunch.Target, []string, error) {
	if len(args) < 4 || args[2] != "--" {
		return remotelaunch.Target{}, nil, errors.New(usage)
	}
	port, err := strconv.Atoi(args[1])
	if err != nil || port < 1 || port > 65535 {
		return remotelaunch.Target{}, nil, fmt.Errorf("invalid port %q", args[1])
	}
	return remotelaunch.Target{Host: args[0], Port: port}, args[3:], nil
}

func main() {
	target, viewer, err := parseArgs(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, "remote-launch:", err)
		os.Exit(2)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	deps := remotelaunch.Deps{
		Probe:        nixcache.Reachable,
		FreePort:     freePort,
		StartForward: startForward,
		RunViewer:    runViewer,
		ReadyTimeout: 15 * time.Second,
		PollInterval: 250 * time.Millisecond,
	}
	if t := sshrelay.NewCtl(nixcache.ExecRunner{}); t != nil {
		deps.Relay = t
	}
	code, err := remotelaunch.Run(ctx, target, viewer, deps)
	if err != nil {
		fmt.Fprintln(os.Stderr, "remote-launch:", err)
	}
	stop()
	os.Exit(code)
}
