package gastown

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// AdvanceResult reports whether accepted branches could become the new base.
type AdvanceResult struct {
	Status   string
	Branches []string
	Conflict string
	Checks   []CheckResult
	Detail   string
}

// AdvanceBase merges gate-accepted branches into the swarm's own base, so the
// next item starts from the work already accepted instead of from the original
// main. The combined result must pass the trusted checks before the base moves.
// Only the swarm's staging repository and its rig repository change; the
// user's repository is never touched.
func (s *Swarm) AdvanceBase(branches []string) AdvanceResult {
	res := AdvanceResult{Status: "error", Branches: branches}
	fail := func(err error) AdvanceResult { res.Detail = err.Error(); return res }
	if len(branches) == 0 {
		res.Status = "none"
		return res
	}
	base := s.base()
	work := filepath.Join(s.Dir(), "advance")
	if err := os.RemoveAll(work); err != nil {
		return fail(err)
	}
	if err := os.MkdirAll(filepath.Dir(work), 0o700); err != nil {
		return fail(err)
	}
	if _, err := runGit("", "clone", "-q", s.Staging(), work); err != nil {
		return fail(err)
	}
	if _, err := runGit(work, "checkout", "-q", "-B", "advance", "origin/"+base); err != nil {
		return fail(err)
	}
	for _, branch := range branches {
		if _, err := runGit(work, "merge", "--no-ff", "--no-edit", "-q", "origin/"+branch); err != nil {
			_, _ = runGit(work, "merge", "--abort")
			res.Status, res.Conflict = "conflict", branch
			return res
		}
	}
	res.Checks = s.R.RunChecks(work, s.Cfg.Checks, filepath.Join(s.Dir(), "gate-logs", "advance"))
	for _, c := range res.Checks {
		if c.Exit != 0 {
			res.Status = "fail"
			return res
		}
	}
	if _, err := runGit(work, "push", "-q", "origin", "advance:refs/heads/"+base); err != nil {
		return fail(err)
	}
	if _, err := runGit("", "-C", s.RigRepo(), "fetch", "-q", "origin"); err != nil {
		return fail(err)
	}
	tip, err := runGit("", "-C", s.RigRepo(), "rev-parse", "origin/"+base)
	if err != nil {
		return fail(err)
	}
	if _, err := runGit("", "-C", s.RigRepo(), "update-ref", "refs/heads/"+base, strings.TrimSpace(tip)); err != nil {
		return fail(err)
	}
	res.Status = "pass"
	return res
}

func (r AdvanceResult) problem() string {
	switch r.Status {
	case "conflict":
		return r.Conflict + " conflicts with the work already accepted"
	case "fail":
		return "the checks fail on the combined result"
	case "error":
		return r.Detail
	}
	return r.Status
}

// CampaignAdvance advances the base by hand with the named branches.
func (s *Swarm) CampaignAdvance(branches []string) error {
	res := s.AdvanceBase(branches)
	if res.Status != "pass" && res.Status != "none" {
		return fmt.Errorf("base not advanced: %s", res.problem())
	}
	fmt.Fprintf(s.Out, "base advanced with %d branch(es); the next goals start from it\n", len(branches))
	return nil
}
