package netconsole

import (
	"fmt"
	"strings"
	"testing"
)

// readMap stands in for os.ReadFile; a key absent from the map simulates a
// missing sysfs parameter file.
func readMap(files map[string]string) func(string) ([]byte, error) {
	return func(path string) ([]byte, error) {
		if v, ok := files[path]; ok {
			return []byte(v), nil
		}
		return nil, fmt.Errorf("no such file: %s", path)
	}
}

func TestVerifyPstoreAcceptsActiveBackend(t *testing.T) {
	cases := []struct {
		always, disable string
	}{
		{"Y\n", "N\n"}, // kernel bool rendering
		{"1", "0"},     // numeric rendering
	}
	for _, c := range cases {
		files := map[string]string{
			LivePstoreParams.AlwaysKmsgDump: c.always,
			LivePstoreParams.PstoreDisable:  c.disable,
		}
		if err := VerifyPstore(readMap(files), LivePstoreParams); err != nil {
			t.Errorf("VerifyPstore(always=%q disable=%q): %v", c.always, c.disable, err)
		}
	}
}

func TestVerifyPstoreRejectsInactiveBackend(t *testing.T) {
	// expected: parameter set, error substring (values render lowercased).
	cases := []struct {
		name            string
		always, disable string // empty string = file absent
		wantPath        string
		wantSubstrings  []string
	}{
		{"dump disabled", "N\n", "N\n", LivePstoreParams.AlwaysKmsgDump, []string{"= \"n\", want true"}},
		{"efi_pstore disabled", "Y\n", "Y\n", LivePstoreParams.PstoreDisable, []string{"= \"y\", want false"}},
		{"missing always param", "", "N\n", LivePstoreParams.AlwaysKmsgDump, []string{"no such file"}},
		{"missing disable param", "Y\n", "", LivePstoreParams.PstoreDisable, []string{"no such file"}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			files := map[string]string{}
			if c.always != "" {
				files[LivePstoreParams.AlwaysKmsgDump] = c.always
			}
			if c.disable != "" {
				files[LivePstoreParams.PstoreDisable] = c.disable
			}
			err := VerifyPstore(readMap(files), LivePstoreParams)
			if err == nil {
				t.Fatal("expected rejection")
			}
			if !strings.Contains(err.Error(), c.wantPath) {
				t.Errorf("error %q missing path %q", err, c.wantPath)
			}
			for _, s := range c.wantSubstrings {
				if !strings.Contains(err.Error(), s) {
					t.Errorf("error %q missing %q", err, s)
				}
			}
		})
	}
}
