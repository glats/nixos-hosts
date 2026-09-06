package gitutil

import "testing"

func TestParseWorktreeList(t *testing.T) {
	tests := []struct {
		name string
		out  string
		want []Worktree
	}{
		{
			name: "empty output",
			out:  "",
			want: nil,
		},
		{
			name: "single attached worktree",
			out: "worktree /home/glats/.nixos\n" +
				"HEAD abcdef1234567890\n" +
				"branch refs/heads/main\n\n",
			want: []Worktree{
				{Path: "/home/glats/.nixos", Head: "abcdef1234567890", Branch: "refs/heads/main"},
			},
		},
		{
			name: "main plus linked worktree",
			out: "worktree /home/glats/.nixos\n" +
				"HEAD abcdef1234567890\n" +
				"branch refs/heads/main\n" +
				"\n" +
				"worktree /home/glats/.nixos/.worktrees/feat/x\n" +
				"HEAD 1234567890abcdef\n" +
				"branch refs/heads/feat/x\n",
			want: []Worktree{
				{Path: "/home/glats/.nixos", Head: "abcdef1234567890", Branch: "refs/heads/main"},
				{Path: "/home/glats/.nixos/.worktrees/feat/x", Head: "1234567890abcdef", Branch: "refs/heads/feat/x"},
			},
		},
		{
			name: "detached and bare entries",
			out: "worktree /srv/bare\n" +
				"bare\n" +
				"\n" +
				"worktree /tmp/wt\n" +
				"HEAD deadbeefdeadbeef\n" +
				"detached\n",
			want: []Worktree{
				{Path: "/srv/bare", Bare: true},
				{Path: "/tmp/wt", Head: "deadbeefdeadbeef", Detached: true},
			},
		},
		{
			name: "attribute line before any header is ignored",
			out:  "HEAD abcdef1234567890\nworktree /repo\n",
			want: []Worktree{{Path: "/repo", Head: ""}},
		},
		{
			name: "unknown attribute line ignored",
			out: "worktree /repo\n" +
				"locked why\n" +
				"branch refs/heads/main\n",
			want: []Worktree{{Path: "/repo", Branch: "refs/heads/main"}},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ParseWorktreeList(tt.out)
			if len(got) != len(tt.want) {
				t.Fatalf("ParseWorktreeList() = %+v, want %+v", got, tt.want)
			}
			for i := range got {
				if got[i] != tt.want[i] {
					t.Errorf("entry[%d] = %+v, want %+v", i, got[i], tt.want[i])
				}
			}
		})
	}
}

func TestMainWorktree(t *testing.T) {
	tests := []struct {
		name string
		out  string
		want string
	}{
		{name: "empty output yields empty root", out: "", want: ""},
		{name: "first entry wins", out: "worktree /main\nbranch refs/heads/main\n\nworktree /other\n", want: "/main"},
		{name: "single linked worktree", out: "worktree /repo/.worktrees/x\n", want: "/repo/.worktrees/x"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := MainWorktree(tt.out); got != tt.want {
				t.Errorf("MainWorktree() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestInWorktrees(t *testing.T) {
	tests := []struct {
		name         string
		dir          string
		worktreesDir string
		want         bool
	}{
		{name: "exact match", dir: "/repo/.worktrees", worktreesDir: "/repo/.worktrees", want: true},
		{name: "nested", dir: "/repo/.worktrees/feat/x", worktreesDir: "/repo/.worktrees", want: true},
		{name: "outside", dir: "/repo", worktreesDir: "/repo/.worktrees", want: false},
		{name: "similar sibling prefix (bash parity)", dir: "/repo/.worktrees2", worktreesDir: "/repo/.worktrees", want: true},
		{name: "empty worktreesDir never matches", dir: "/anything", worktreesDir: "", want: false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := InWorktrees(tt.dir, tt.worktreesDir); got != tt.want {
				t.Errorf("InWorktrees(%q, %q) = %v, want %v", tt.dir, tt.worktreesDir, got, tt.want)
			}
		})
	}
}

func TestWorktreeName(t *testing.T) {
	tests := []struct {
		name         string
		dir          string
		worktreesDir string
		want         string
	}{
		{name: "simple", dir: "/repo/.worktrees/my-feature", worktreesDir: "/repo/.worktrees", want: "my-feature"},
		{name: "nested slashes", dir: "/repo/.worktrees/feat/multi-github-identity", worktreesDir: "/repo/.worktrees", want: "feat/multi-github-identity"},
		{name: "no prefix returns unchanged", dir: "/elsewhere", worktreesDir: "/repo/.worktrees", want: "/elsewhere"},
		// Bash ${PWD#$WORKTREES_DIR/} with an empty WORKTREES_DIR strips a
		// leading "/" — unreachable in the real flow (guarded by the
		// non-empty REPO_ROOT check) but pinned here for expansion parity.
		{name: "empty worktreesDir strips leading slash (bash parity)", dir: "/elsewhere", worktreesDir: "", want: "elsewhere"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := WorktreeName(tt.dir, tt.worktreesDir); got != tt.want {
				t.Errorf("WorktreeName(%q, %q) = %q, want %q", tt.dir, tt.worktreesDir, got, tt.want)
			}
		})
	}
}

func TestValidName(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want bool
	}{
		{name: "simple", in: "my-feature", want: true},
		{name: "dotted", in: "fix.1", want: true},
		{name: "nested", in: "feat/multi-github-identity", want: true},
		{name: "underscore", in: "wip_2", want: true},
		{name: "single char", in: "x", want: true},
		{name: "empty", in: "", want: false},
		{name: "leading slash", in: "/abs", want: false},
		{name: "leading dot", in: ".hidden", want: false},
		{name: "leading dash", in: "-x", want: false},
		{name: "spaces", in: "has space", want: false},
		{name: "trailing colon", in: "bad:name", want: false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := ValidName(tt.in); got != tt.want {
				t.Errorf("ValidName(%q) = %v, want %v", tt.in, got, tt.want)
			}
		})
	}
}
