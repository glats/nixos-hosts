package gastown

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// Abandon releases the task left hooked by the last failed run. Partial work is
// kept in a git stash inside the worker clone and the task returns to open; it
// is never closed.
// lastTaskRecord returns the newest bead.json of the given crew. Records written
// before crews were recorded belong to the default worker.
func lastTaskRecord(state string, p Project) (string, taskRecord, error) {
	records, _ := filepath.Glob(filepath.Join(state, "runs", p.Rig, "*", "bead.json"))
	sort.Strings(records)
	for i := len(records) - 1; i >= 0; i-- {
		var rec taskRecord
		data, err := os.ReadFile(records[i])
		if err != nil || json.Unmarshal(data, &rec) != nil {
			return "", taskRecord{}, errors.New("last task record is unreadable")
		}
		if rec.Crew == "" {
			rec.Crew = "worker"
		}
		if rec.Crew != p.Crew {
			continue
		}
		if !ValidBeadID(rec.ID) {
			return "", taskRecord{}, errors.New("last task record is unreadable")
		}
		return records[i], rec, nil
	}
	return "", taskRecord{}, errors.New("no previous task found")
}

func (r *Runner) Abandon(p Project) (string, error) {
	c := r.Config
	recordPath, assigned, err := lastTaskRecord(c.State, p)
	if err != nil {
		return "", err
	}
	last := Report{BeadID: assigned.ID}
	if data, err := os.ReadFile(filepath.Join(filepath.Dir(recordPath), "report.json")); err == nil {
		_ = json.Unmarshal(data, &last)
	}
	if last.Status == "pass" {
		return "", errors.New("the last task already completed; nothing to abandon")
	}
	workspace := r.Workspace(p)
	env := CoordinatorEnv(c, r.Town(), p.Rig, p.Crew)
	env = append(env, "PATH="+filepath.Dir(c.Tmux)+":"+envValue(env, "PATH"))
	run := func(program string, args ...string) (Result, error) {
		res, runErr := r.Exec.Run(Command{Name: program, Args: args, Dir: workspace, Env: env, Timeout: time.Minute})
		if runErr == nil && res.Exit != 0 {
			runErr = errors.New(filepath.Base(program) + " " + strings.Join(args, " ") + " failed: " + strings.TrimSpace(string(res.Stderr)))
		}
		return res, runErr
	}
	if _, err := run(c.GT, "dolt", "start"); err != nil {
		return "", err
	}
	defer func() { _, _ = run(c.GT, "dolt", "stop") }()
	hook, err := run(c.GT, "hook", "show", p.Rig+"/crew/"+p.Crew, "--json")
	if err != nil {
		return "", err
	}
	var held struct {
		Status string `json:"status"`
		BeadID string `json:"bead_id"`
	}
	if json.Unmarshal(hook.Stdout, &held) != nil || held.Status != "hooked" || held.BeadID != last.BeadID {
		return "", errors.New("the hook does not hold the failed task " + last.BeadID)
	}
	status, err := run("git", "status", "--porcelain")
	if err != nil {
		return "", err
	}
	message := "preserved work"
	if strings.TrimSpace(string(status.Stdout)) != "" {
		if _, err := run("git", "stash", "push", "--include-untracked", "-m", "gastown abandoned "+last.BeadID); err != nil {
			return "", err
		}
		message = "partial work saved in `git stash` of " + workspace
	}
	if _, err := run(c.GT, "unsling", "--force", last.BeadID); err != nil {
		return "", err
	}
	return "task " + last.BeadID + " released (open); " + message, nil
}
