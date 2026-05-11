# Task Breakdown: sync-from-nixos-to-mac-again-because-new-changes-on-nixos

## Phase 1: Foundation (no dependencies) - Can run in parallel

### 1.1 Add opencode-npm-packages package (mact2)
**What**: Create opencode-npm-packages derivation on mact2 by copying from rog
**Files**: 
- Create: `~/.config/nix/pkgs/opencode-npm-packages/default.nix`
- Create: `~/.config/nix/pkgs/opencode-npm-packages/versions.json`  
- Create: `~/.config/nix/pkgs/opencode-npm-packages/node-modules.json`
**Host**: mact2
**Dependencies**: None
**Acceptance Criteria**:
- Files match exactly the rog versions (content identical)
- Derivation builds successfully: `nix build .#packages.x86_64-darwin.opencode-npm-packages`
**Verification Commands**:
- `diff ~/.config/nix/pkgs/opencode-npm-packages/default.nix /home/glats/.nixos/pkgs/opencode-npm-packages/default.nix`
- `diff ~/.config/nix/pkgs/opencode-npm-packages/versions.json /home/glats/.nixos/pkgs/opencode-npm-packages/versions.json`
- `diff ~/.config/nix/pkgs/opencode-npm-packages/node-modules.json /home/glats/.nixos/pkgs/opencode-npm-packages/node-modules.json`
- `nix build .#packages.x86_64-darwin.opencode-npm-packages`
**Estimated Complexity**: S

### 1.2 Fix rog cmp bug: coreutils -> diffutils (rog)
**What**: Fix the cmp bug in rog's opencode.nix module by changing coreutils to diffutils
**Files**: 
- Modify: `/home/glats/.nixos/modules/home/opencode.nix`
**Host**: rog
**Dependencies**: None
**Acceptance Criteria**:
- Line containing `${pkgs.coreutils}/bin/cmp` changed to `${pkgs.diffutils}/bin/cmp`
**Verification Commands**:
- `grep "diffutils.*cmp" /home/glats/.nixos/modules/home/opencode.nix`
- `! grep "coreutils.*cmp" /home/glats/.nixos/modules/home/opencode.nix`
**Estimated Complexity**: S

### 1.3 Bump gentle-ai version on mact2
**What**: Update gentle-ai package from v1.24.3 to v1.25.4 on mact2 with correct darwin URL and hash
**Files**: 
- Modify: `~/.config/nix/pkgs/gentle-ai/default.nix`
**Host**: mact2
**Dependencies**: None
**Acceptance Criteria**:
- version = "1.25.4"
- URL uses darwin_amd64.tar.gz instead of linux_amd64.tar.gz
- Correct sha256 hash for darwin binary
**Verification Commands**:
- `grep "version = \"1.25.4\"" ~/.config/nix/pkgs/gentle-ai/default.nix`
- `grep "darwin_amd64" ~/.config/nix/pkgs/gentle-ai/default.nix`
- `nix build .#packages.x86_64-darwin.gentle-ai`
**Estimated Complexity**: S

## Phase 2: Overlay + flake (depends on Phase 1 completion)

### 2.1 Add extraCommands to gentle-ai-assets (mact2)
**What**: Add extraCommands parameter and overlay logic to gentle-ai-assets
**Files**: 
- Modify: `~/.config/nix/pkgs/gentle-ai-assets/default.nix`
**Host**: mact2
**Dependencies**: 1.1 (opencode-npm-packages exists)
**Acceptance Criteria**:
- File accepts `extraCommands ? null` parameter
- Contains logic to overlay extraCommands when not null
**Verification Commands**:
- `grep "extraCommands" ~/.config/nix/pkgs/gentle-ai-assets/default.nix`
- `grep "overlay" ~/.config/nix/pkgs/gentle-ai-assets/default.nix | grep -i command`
- `nix build .#packages.x86_64-darwin.gentle-ai-assets`
**Estimated Complexity**: M

### 2.2 Add opencode overlay + npm-packages + extraCommands (mact2)
**What**: Configure overlays to include opencode pin, npm-packages, and extraCommands
**Files**: 
- Modify: `~/.config/nix/overlays/default.nix`
**Host**: mact2
**Dependencies**: 
- 1.1 (opencode-npm-packages)
- 2.1 (gentle-ai-assets with extraCommands)
**Acceptance Criteria**:
- Overlay includes opencode pin via overrideAttrs
- Overlay includes opencode-npm-packages
- Overlay passes extraCommands to gentle-ai-assets
**Verification Commands**:
- `grep "opencode" ~/.config/nix/overlays/default.nix | grep -i override`
- `grep "opencode-npm-packages" ~/.config/nix/overlays/default.nix`
- `grep "extraCommands" ~/.config/nix/overlays/default.nix`
- `nix build .#packages.x86_64-darwin.opencode`
**Estimated Complexity**: M

### 2.3 Add TUI plugin flake inputs (mact2)
**What**: Add TUI plugin flake inputs to mact2 flake.nix
**Files**: 
- Modify: `~/.config/nix/flake.nix` (inputs section)
**Host**: mact2
**Dependencies**: None (but should run after Phase 1 for consistency)
**Acceptance Criteria**:
- Added sub-agent-statusline flake input
- Added sdd-engram-plugin flake input
- Both inputs follow nixpkgs
**Verification Commands**:
- `grep "sub-agent-statusline" ~/.config/nix/flake.nix`
- `grep "sdd-engram-plugin" ~/.config/nix/flake.nix`
- `nix flake info`
**Estimated Complexity**: S

### 2.4 Add opencode-npm-packages to flake outputs (mact2)
**What**: Add opencode-npm-packages to flake.nix outputs
**Files**: 
- Modify: `~/.config/nix/flake.nix` (outputs section)
**Host**: mact2
**Dependencies**: 
- 1.1 (opencode-npm-packages)
- 2.3 (TUI inputs added)
**Acceptance Criteria**:
- opencode-npm-packages package available in outputs
- Can be referenced as `packages.x86_64-darwin.opencode-npm-packages`
**Verification Commands**:
- `grep "opencode-npm-packages" ~/.config/nix/flake.nix`
- `nix build .#packages.x86_64-darwin.opencode-npm-packages`
**Estimated Complexity**: S

## Phase 3: Content (depends on Phase 2 completion)

### 3.1 Copy 14 commands .md files (mact2)
**What**: Copy all command markdown files from rog to mact2
**Files**: 
- Create: `~/.config/nix/home/opencode/commands/` directory
- Create: 14 *.md files in commands directory (copy from rog)
**Host**: mact2
**Dependencies**: 
- 2.2 (overlays configured)
- 2.4 (flake outputs include npm-packages)
**Acceptance Criteria**:
- All 14 command files from rog present in mact2
- File contents identical to rog versions
**Verification Commands**:
- `ls ~/.config/nix/home/opencode/commands/ | wc -l` (should be 14)
- `diff -q /home/glats/.nixos/modules/home/opencode/commands/ ~/.config/nix/home/opencode/commands/` (no output if identical)
**Estimated Complexity**: L

### 3.2 Update mact2 providers.nix (mact2)
**What**: Add missing models to providers.nix and add kimi-k2.6
**Files**: 
- Modify: `~/.config/nix/home/opencode/providers.nix`
**Host**: mact2
**Dependencies**: 
- 2.2 (overlays configured)
**Acceptance Criteria**:
- Contains all models from rog's providers.nix (635 lines)
- Includes kimi-k2.6 model in appropriate provider
- Maintains only 3 providers: nvidia, opencode-go, github-copilot
**Verification Commands**:
- `wc -l ~/.config/nix/home/opencode/providers.nix` (should be ~635)
- `grep "kimi-k2.6" ~/.config/nix/home/opencode/providers.nix`
- `grep -c "provider" ~/.config/nix/home/opencode/providers.nix` (should be 3)
**Estimated Complexity**: M

## Phase 4: Integration (depends on Phase 2+3 completion)

### 4.1 Rewrite mact2 opencode.nix (mact2)
**What**: Rewrite activation script to remove npm install, use cp from derivation, clean JSON generation
**Files**: 
- Modify: `~/.config/nix/home/opencode.nix`
**Host**: mact2
**Dependencies**: 
- 2.1 (gentle-ai-assets with extraCommands)
- 2.2 (overlays configured)
- 2.4 (flake outputs include npm-packages)
- 3.1 (commands files copied)
- 3.2 (providers.nix updated)
**Acceptance Criteria**:
- No npm install commands in activation script
- Uses cp from derivation for package.json and node_modules
- Clean JSON generation (removed plugin + experimental keys)
- Uses diffutils for cmp instead of coreutils
- Darwin-specific commands: rm + cp instead of cp --remove-destination, chmod u+w instead of chmod 644
**Verification Commands**:
- `! grep -i "npm install" ~/.config/nix/home/opencode.nix`
- `grep "cp.*package.json" ~/.config/nix/home/opencode.nix`
- `grep "diffutils.*cmp" ~/.config/nix/home/opencode.nix`
- `grep "rm.*cp" ~/.config/nix/home/opencode.nix | grep -v "#"`
- `grep "chmod u+w" ~/.config/nix/home/opencode.nix`
**Estimated Complexity**: L

### 4.2 Add PATH priority fix (mact2)
**What**: Add PATH priority fix in home config using programs.zsh.initExtra
**Files**: 
- Modify: `~/.config/nix/home/default.nix` (or appropriate home config file)
**Host**: mact2
**Dependencies**: 
- 4.1 (opencode.nix rewritten)
**Acceptance Criteria**:
- Added programs.zsh.initExtra with nix paths prepended
- PATH prioritizes nix binaries over system binaries
**Verification Commands**:
- `grep "programs.zsh.initExtra" ~/.config/nix/home/default.nix`
- `grep "nix.*path" ~/.config/nix/home/default.nix | head -1`
**Estimated Complexity**: S

