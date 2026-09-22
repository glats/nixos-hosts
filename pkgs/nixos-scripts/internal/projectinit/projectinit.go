// Package projectinit creates the local state required for an Engram/OpenSpec project.
package projectinit

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
)

var namePattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]*$`)

type Options struct {
	Name       string
	DryRun     bool
	Force      bool
	OpenSpec   func(string) error
	NoOpenSpec bool
}

type Result struct {
	Path     string
	Git      bool
	Engram   string
	OpenSpec string
}

func Init(path string, options Options) (Result, error) {
	path, err := filepath.Abs(path)
	if err != nil {
		return Result{}, fmt.Errorf("resolve project path: %w", err)
	}
	info, err := os.Stat(path)
	if err != nil {
		return Result{}, fmt.Errorf("project directory: %w", err)
	}
	if !info.IsDir() {
		return Result{}, errors.New("project path must be a directory")
	}
	if options.Name == "" {
		options.Name = filepath.Base(path)
	}
	if !namePattern.MatchString(options.Name) {
		return Result{}, errors.New("project name must start with an alphanumeric character and contain only letters, digits, '.', '_' or '-'")
	}

	configPath := filepath.Join(path, ".engram", "config.json")
	state, err := engramState(configPath, options.Name)
	if err != nil {
		return Result{}, err
	}
	if state == "conflict" && !options.Force {
		return Result{}, fmt.Errorf("%s already identifies a different project; use --force to replace it", configPath)
	}
	openSpec := "current"
	if options.NoOpenSpec {
		openSpec = "skipped"
	} else if !exists(filepath.Join(path, "openspec", "config.yaml")) {
		openSpec = "created"
	}
	if openSpec == "created" && !options.DryRun {
		if options.OpenSpec == nil {
			return Result{}, errors.New("OpenSpec initializer is not configured")
		}
		if err := options.OpenSpec(path); err != nil {
			return Result{}, fmt.Errorf("initialize OpenSpec: %w", err)
		}
	}
	if state != "current" && !options.DryRun {
		if err := writeEngramConfig(configPath, options.Name); err != nil {
			return Result{}, err
		}
	}

	return Result{
		Path:     path,
		Git:      hasGit(path),
		Engram:   state,
		OpenSpec: openSpec,
	}, nil
}

func writeEngramConfig(path, name string) error {
	data, _ := json.MarshalIndent(struct {
		ProjectName string `json:"project_name"`
	}{name}, "", "  ")
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("create Engram directory: %w", err)
	}
	tmp, err := os.CreateTemp(dir, ".config-*")
	if err != nil {
		return fmt.Errorf("create Engram configuration: %w", err)
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	if err := tmp.Chmod(0o644); err == nil {
		_, err = tmp.Write(append(data, '\n'))
	}
	if closeErr := tmp.Close(); err == nil {
		err = closeErr
	}
	if err != nil {
		return fmt.Errorf("write Engram configuration: %w", err)
	}
	if err := os.Rename(tmpPath, path); err != nil {
		return fmt.Errorf("replace Engram configuration: %w", err)
	}
	return nil
}

func engramState(path, name string) (string, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return "created", nil
	}
	if err != nil {
		return "", fmt.Errorf("read Engram configuration: %w", err)
	}
	var config struct {
		ProjectName string `json:"project_name"`
	}
	if err := json.Unmarshal(data, &config); err != nil {
		return "", fmt.Errorf("parse Engram configuration: %w", err)
	}
	if config.ProjectName == name {
		return "current", nil
	}
	return "conflict", nil
}

func hasGit(path string) bool {
	for {
		if exists(filepath.Join(path, ".git")) {
			return true
		}
		parent := filepath.Dir(path)
		if parent == path {
			return false
		}
		path = parent
	}
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
