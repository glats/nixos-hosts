# Spec: Shared Home Manager Modules — No Host Conditionals

## Purpose

Shared modules under `home-linux/` MUST NOT contain `hostName` conditionals. All host-specific branching MUST occur at the import site in each host's module list. This ensures host differences are explicit at the import level.

## Requirements

### Requirement: No host conditionals in shared home modules

The `home-linux/` directory MUST NOT contain any `hostName` conditionals. All host-specific branching MUST occur at the import site in each host's module list.

#### Scenario: Grep returns zero hostName matches

- GIVEN the refactor is complete
- WHEN `grep -r 'hostName' home-linux/` is executed
- THEN zero matches are returned

#### Scenario: New shared module has no conditionals

- GIVEN a developer adds a new module to `home-linux/`
- WHEN the module is reviewed
- THEN it MUST NOT contain `hostName` branching logic

### Requirement: Shared btop theme fragment

`home-linux/btop-theme.nix` MUST write `~/.config/btop/themes/nix-colors.theme` using `config.colorScheme.palette` base16 colors. It MUST NOT reference `hostName`. It MUST be included in `home-linux/shared-modules.nix`.

#### Scenario: All linux hosts receive the theme file

- GIVEN any linux host (rog, thinkcentre, t14) evaluates its home configuration
- WHEN the home-manager build completes
- THEN `~/.config/btop/themes/nix-colors.theme` exists with the correct base16 color mappings

### Requirement: File-based btop config for rog and thinkcentre

`home-linux/btop-file.nix` MUST write `~/.config/btop/btop.conf` via `home.file` with the full btop configuration (color_theme, presets, shown_boxes, gpu settings, etc.). It MUST NOT reference `hostName`. It MUST be imported by `hosts/rog/home/modules.nix` and `hosts/thinkcentre/home/modules.nix`.

#### Scenario: rog produces identical btop.conf as before refactor

- GIVEN the rog host evaluates its home configuration after the refactor
- WHEN `~/.config/btop/btop.conf` is generated
- THEN the file content matches the pre-refactor output exactly

#### Scenario: thinkcentre produces identical btop.conf as before refactor

- GIVEN the thinkcentre host evaluates its home configuration after the refactor
- WHEN `~/.config/btop/btop.conf` is generated
- THEN the file content matches the pre-refactor output exactly

### Requirement: HM settings-based btop config for t14

`home-linux/btop-settings.nix` MUST set `programs.btop.settings` with `lib.mkForce` on each key, matching the current `mkIf (hostName == "t14")` block. It MUST NOT reference `hostName`. It MUST be imported by `hosts/t14/home/omarchy.nix`.

#### Scenario: t14 btop settings override omarchy defaults

- GIVEN the t14 host evaluates its home configuration after the refactor
- WHEN `programs.btop.settings` is resolved
- THEN every key uses `lib.mkForce` and the values match the pre-refactor output exactly

#### Scenario: t14 theme file is still deployed

- GIVEN the t14 host includes `btop-settings.nix`
- WHEN the home-manager build completes
- THEN `~/.config/btop/themes/nix-colors.theme` is present (provided by `btop-theme.nix` via shared-modules or explicit import)

### Requirement: Import list correctness

`home-linux/shared-modules.nix` MUST replace `./btop.nix` with `./btop-theme.nix`. The original `./btop.nix` MUST be deleted. Each host's module list MUST import exactly the btop fragment that matches its pre-refactor behavior.

#### Scenario: shared-modules.nix no longer references btop.nix

- GIVEN the refactor is complete
- WHEN `home-linux/shared-modules.nix` is read
- THEN it contains `./btop-theme.nix` and does NOT contain `./btop.nix`

#### Scenario: Flake evaluation passes

- GIVEN the refactor is complete
- WHEN `nix flake check --no-build` is executed
- THEN it passes with exit code 0

### Requirement: Shell-GPT Home Manager Module

(Originates from `openspec/changes/archive/2026-07-01-ai-command-assist/spec.md`)

The system MUST provide a Home Manager module at `home-linux/shell-gpt.nix` that
installs and configures shell-gpt via declarative Nix options. The module MUST
NOT be imported in `home-linux/shared-modules.nix`; it MUST be imported
per-host (like the conky-rog pattern).

The module MUST expose `home.shell-gpt` options:
- `enable` (boolean, default `false`)
- `model` (string, default `"nvidia/nemotron-3-ultra-550b-a55b"`)
- `baseUrl` (string, default `"https://integrate.api.nvidia.com/v1"`)

When enabled, the module MUST install `pkgs.shell-gpt` and set
`home.sessionVariables` for `API_BASE_URL`, `OPENAI_API_KEY`, `DEFAULT_MODEL`,
`SHELL_INTERACTION`, and `DEFAULT_EXECUTE_SHELL_CMD`.

When disabled, the module MUST NOT install `pkgs.shell-gpt` and MUST NOT set
any shell-gpt environment variables.

#### Scenario: Module enabled on rog

- GIVEN the rog host imports `home-linux/shell-gpt.nix` and has `home.shell-gpt.enable = true`
- WHEN `home-manager switch` runs
- THEN `pkgs.shell-gpt` is installed in the user's profile
- AND `API_BASE_URL` env var is set to `"https://integrate.api.nvidia.com/v1"`
- AND `OPENAI_API_KEY` env var is set to `"$NVIDIA_API_KEY"` (direct string, resolved at runtime)
- AND `DEFAULT_MODEL` env var is set to `"nvidia/nemotron-3-ultra-550b-a55b"`
- AND `SHELL_INTERACTION` env var is set to `"true"`
- AND `DEFAULT_EXECUTE_SHELL_CMD` env var is set to `"false"`

#### Scenario: Module disabled on thinkcentre

- GIVEN the thinkcentre host imports `home-linux/shell-gpt.nix` and has `home.shell-gpt.enable = false`
- WHEN `home-manager switch` runs
- THEN `pkgs.shell-gpt` is NOT in the user's profile
- AND no shell-gpt session variables are set

#### Scenario: Default options apply when no overrides given

- GIVEN the module is enabled without custom `model` or `baseUrl` options
- WHEN `home-manager switch` runs
- THEN `DEFAULT_MODEL` env var is `"nvidia/nemotron-3-ultra-550b-a55b"`
- AND `API_BASE_URL` env var is `"https://integrate.api.nvidia.com/v1"`

#### Scenario: Custom model override

- GIVEN `home.shell-gpt.model = "deepseek-ai/deepseek-v4-flash"`
- WHEN `home-manager switch` runs
- THEN `DEFAULT_MODEL` env var is `"deepseek-ai/deepseek-v4-flash"`

#### Scenario: Custom baseUrl override for future provider switch

- GIVEN `home.shell-gpt.baseUrl = "http://localhost:11434/v1"`
- WHEN `home-manager switch` runs
- THEN `API_BASE_URL` env var is `"http://localhost:11434/v1"`

#### Scenario: Disabled comment example in host config

- GIVEN a host config has `# home.shell-gpt.enable = false;` as a commented line
- WHEN a user reads the host config file
- THEN they see where to enable or disable the module
- AND the commented line does not affect build output

#### Scenario: Shared module list exclusion

- GIVEN the module file exists at `home-linux/shell-gpt.nix`
- WHEN `home-linux/shared-modules.nix` is examined
- THEN `./shell-gpt.nix` is NOT present in the import list
- AND the import list remains unchanged from pre-change state

#### Scenario: Flake evaluation passes with module imported

- GIVEN the module is imported in at least one host config
- WHEN `nix flake check --no-build` is executed
- THEN it passes with exit code 0

### Requirement: shell-gpt CLI works with NVIDIA NIM

(Originates from `openspec/changes/archive/2026-07-01-ai-command-assist/spec.md`)

The installed shell-gpt MUST accept natural language input and generate shell
commands via the nvidia NIM API. The confirmation prompt MUST appear before any
command is executed. The `OPENAI_API_KEY` environment variable MUST resolve to
the `NVIDIA_API_KEY` value exported by `shared/opencode.nix` (sops-nix).

#### Scenario: One-shot command generation

- GIVEN shell-gpt is installed and `NVIDIA_API_KEY` is available in the environment
- WHEN the user runs `sgpt --shell "list files sorted by size"`
- THEN a valid shell command is generated (e.g., `ls -lhS`)
- AND the command is displayed with an `[E/M/D/A]` confirmation prompt

#### Scenario: REPL mode

- GIVEN shell-gpt is installed
- WHEN the user runs `sgpt --repl temp --shell`
- THEN an interactive REPL prompt appears
- AND the user can enter multiple natural language requests
- AND each response shows the `[E/M/D/A]` confirmation prompt

#### Scenario: API key available from sops-nix

- GIVEN `NVIDIA_API_KEY` is exported by `shared/opencode.nix` via sops-nix
- WHEN `sgpt --shell "test connection"` is run
- THEN shell-gpt's OpenAI client authenticates with nvidia NIM
- AND no authentication error is shown

#### Scenario: Describe mode

- GIVEN a command is generated and displayed
- WHEN the user selects `[D]escribe`
- THEN an explanation of what the command does is shown

#### Scenario: Command execution uses shlex.quote

- GIVEN shell-gpt generates a command via `sgpt --shell`
- WHEN the `[E]xecute` option is selected
- THEN the command is passed through `shlex.quote()` before reaching the shell
- AND shell metacharacters (`$()`, backticks, `;`, `&&`, `||`) are quoted as safe literals

#### Scenario: No auto-execution by default

- GIVEN `DEFAULT_EXECUTE_SHELL_CMD` is set to `"false"` in `home.sessionVariables`
- WHEN `sgpt --shell "echo hello"` is run
- THEN the command is displayed but NOT automatically executed
- AND the `[E/M/D/A]` confirmation prompt always appears

### Requirement: Per-host configuration

(Originates from `openspec/changes/archive/2026-07-01-ai-command-assist/spec.md`)

The module MUST support different `model` and `baseUrl` options per host. Each
host MAY independently enable or disable the module. Module configuration MUST
NOT leak between hosts.

#### Scenario: Rog uses nemotron-3-ultra (default model)

- GIVEN rog has `home.shell-gpt.enable = true` with default options
- WHEN `sgpt --shell` is run on rog
- THEN API requests use the nvidia NIM endpoint with model `nvidia/nemotron-3-ultra-550b-a55b`

#### Scenario: Different host uses a different model

- GIVEN thinkcentre has `home.shell-gpt.model = "deepseek-ai/deepseek-v4-flash"`
- WHEN `sgpt --shell` is run on thinkcentre
- THEN API requests use the nvidia NIM endpoint with model `deepseek-ai/deepseek-v4-flash`

#### Scenario: Hosts can be independently disabled

- GIVEN rog has `home.shell-gpt.enable = true` and t14 has `home.shell-gpt.enable = false`
- WHEN `home-manager switch` runs on each host
- THEN rog's profile includes `pkgs.shell-gpt` and env vars
- AND t14's profile does NOT include `pkgs.shell-gpt` or shell-gpt env vars

#### Scenario: t14 optional import with commented-out enable

- GIVEN `hosts/t14/home/omarchy.nix` includes a commented `# home.shell-gpt.enable = false;`
- WHEN `home-manager switch` runs on t14
- THEN t14's profile does NOT contain `pkgs.shell-gpt` or shell-gpt env vars
- AND `nix flake check --no-build` still passes

### Requirement: Zero maintenance overhead

(Originates from `openspec/changes/archive/2026-07-01-ai-command-assist/spec.md`)

The module MUST NOT introduce ongoing maintenance burden. There MUST be no
custom scripts, patches, forks, or derivations for shell-gpt in this
repository. All execution logic MUST come from upstream `pkgs.shell-gpt`.

#### Scenario: shell-gpt updates via nixpkgs

- GIVEN shell-gpt 1.5.1 is installed via `pkgs.shell-gpt`
- WHEN nixpkgs releases shell-gpt 1.6.0 and the flake lock is updated
- THEN the new version is installed without any changes to the HM module

#### Scenario: Module has no custom code

- GIVEN the module is enabled on any host
- WHEN the repository is audited for custom shell-gpt code
- THEN there are no custom Python scripts, shell wrappers, or forked derivations for shell-gpt
- AND the only Nix file related to shell-gpt is `home-linux/shell-gpt.nix`
- AND `home-linux/shell-gpt.nix` contains only declarative HM options and env var assignments

#### Scenario: No new flake inputs required

- GIVEN the change is applied
- WHEN `flake.nix` is examined
- THEN no new inputs are added for shell-gpt
- AND `pkgs.shell-gpt` is resolved from the existing `nixpkgs` flake input

#### Scenario: Module follows existing host-conditional pattern

- GIVEN `home-linux/shell-gpt.nix` is reviewed
- WHEN the module code is examined
- THEN it does NOT contain `hostName`, `networking.hostName`, or any `lib.mkIf (hostName == ...)` conditionals
- AND host differentiation is handled entirely at the import site in each host's module list

## Removed

### Requirement: Monolithic btop.nix with host branching

`home-linux/btop.nix` is removed. Its theme logic moves to `btop-theme.nix`; its rog/thinkcentre config moves to `btop-file.nix`; its t14 settings moves to `btop-settings.nix`.

(Reason: Single source of host-conditional logic violates the per-host import pattern used by all other modules.)
(Migration: Three replacement files, each imported at the appropriate host's module list.)
