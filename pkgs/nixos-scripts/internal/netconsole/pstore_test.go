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

// writeMap records runtime writes; a key absent from allowed simulates a
// read-only parameter file.
func writeMap(allowed map[string]bool) (func(string, []byte) error, *[]string) {
	var written []string
	return func(path string, val []byte) error {
		if !allowed[path] {
			return fmt.Errorf("read-only file system")
		}
		written = append(written, path)
		return nil
	}, &written
}

func TestEnsurePstoreSelfHealsWrongValue(t *testing.T) {
	files := map[string]string{
		LivePstoreParams.AlwaysKmsgDump: "n\n", // default: cmdline not applied yet
		LivePstoreParams.PstoreDisable:  "N\n",
	}
	write, seen := writeMap(map[string]bool{LivePstoreParams.AlwaysKmsgDump: true})
	// the runtime write is visible to the re-read through a shared store:
	mutating := func(path string) ([]byte, error) {
		if path == LivePstoreParams.AlwaysKmsgDump && len(*seen) > 0 {
			return []byte("1"), nil
		}
		return readMap(files)(path)
	}
	if err := EnsurePstore(mutating, write, LivePstoreParams); err != nil {
		t.Fatalf("EnsurePstore: %v", err)
	}
	if len(*seen) != 1 || (*seen)[0] != LivePstoreParams.AlwaysKmsgDump {
		t.Errorf("expected exactly one runtime write to %s, got %v", LivePstoreParams.AlwaysKmsgDump, *seen)
	}
}

func TestEnsurePstoreFailsClosedOnReadOnlyParam(t *testing.T) {
	files := map[string]string{
		LivePstoreParams.AlwaysKmsgDump: "n\n",
		LivePstoreParams.PstoreDisable:  "N\n",
	}
	write, seen := writeMap(nil) // nothing writable
	err := EnsurePstore(readMap(files), write, LivePstoreParams)
	if err == nil {
		t.Fatal("expected error when runtime write is impossible")
	}
	if !strings.Contains(err.Error(), "reboot to apply kernel params") {
		t.Errorf("error should advise reboot, got: %v", err)
	}
	if len(*seen) != 0 {
		t.Errorf("no write should succeed, got %v", *seen)
	}
}

func TestEnsurePstoreNoWriteWhenCorrect(t *testing.T) {
	files := map[string]string{
		LivePstoreParams.AlwaysKmsgDump: "Y\n",
		LivePstoreParams.PstoreDisable:  "0",
	}
	write, seen := writeMap(nil)
	if err := EnsurePstore(readMap(files), write, LivePstoreParams); err != nil {
		t.Fatalf("EnsurePstore: %v", err)
	}
	if len(*seen) != 0 {
		t.Errorf("correct values must not trigger writes, got %v", *seen)
	}
}
