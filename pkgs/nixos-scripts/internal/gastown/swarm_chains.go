package gastown

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"reflect"
	"strings"
)

// SetChains replaces the swarm's agent chains with the ones in a JSON file
// ({"mayor": [...], "polecat": [...]}), keeping every other setting. It runs
// only while the supervisor is stopped, because swarm.json is read once at
// start. The previous file is kept as swarm.json.before-profile.
func (s *Swarm) SetChains(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var chains map[string][]string
	if err := json.Unmarshal(data, &chains); err != nil {
		return fmt.Errorf("chains file %s: %w", path, err)
	}
	for _, role := range []string{"mayor", "polecat"} {
		if len(chains[role]) == 0 {
			return errors.New("chains file " + path + " needs at least one " + role + " agent")
		}
	}
	probe := Config{Claude: "claude", Codex: "codex", OpenCode: "opencode"}
	for role, specs := range chains {
		for _, spec := range specs {
			if _, _, err := AgentPreset(probe, "", "/town", spec, nil); err != nil {
				return fmt.Errorf("%s chain: %w", role, err)
			}
		}
	}
	if reflect.DeepEqual(chains, s.Cfg.Chains) {
		fmt.Fprintln(s.Out, "chains unchanged")
		return nil
	}
	previous, err := os.ReadFile(s.savePath())
	if err != nil {
		return err
	}
	if err := os.WriteFile(s.savePath()+".before-profile", previous, 0o600); err != nil {
		return err
	}
	s.Cfg.Chains = chains
	if err := s.save(); err != nil {
		return err
	}
	fmt.Fprintf(s.Out, "chains updated: mayor=%s polecat=%s\n", strings.Join(chains["mayor"], ","), strings.Join(chains["polecat"], ","))
	return nil
}
