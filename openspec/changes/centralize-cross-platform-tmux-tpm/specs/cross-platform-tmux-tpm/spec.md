# Cross-Platform tmux TPM Specification

## Purpose

Define shared TPM and activation behavior across scoped hosts.

## Requirements

### Requirement: Central TPM Runtime Declaration

The system MUST declare the TPM runtime once in shared config: `tmux-plugins/tpm`, `tmux-plugins/tmux-resurrect`, `tmux-plugins/tmux-continuum`, `tmux-plugins/tmux-sessionist`, `tmux-plugins/tmux-yank`, `tmux-plugins/tmux-open`, and `christoomey/vim-tmux-navigator`, in that order. It MUST set `TMUX_PLUGIN_MANAGER_PATH`, place the loader last, and MUST NOT use `programs.tmux.plugins`.

#### Scenario: Scoped hosts receive the canonical plugin set [rog, thinkcentre, t14, macm5]

- GIVEN a scoped host evaluates its Home Manager tmux configuration
- WHEN the generated tmux configuration is inspected
- THEN it contains the seven repositories once in the specified order
- AND its final TPM command is the loader.

#### Scenario: Platform modules do not create competing plugin managers [rog, thinkcentre, t14, macm5]

- GIVEN Linux and Darwin platform tmux modules are composed with the shared module
- WHEN their effective tmux options are evaluated
- THEN no TPM repository is interpreted as a `programs.tmux.plugins` package value.

### Requirement: Platform tmux Compatibility

The system MUST preserve Linux `escapeTime = 0` on `rog`, `thinkcentre`, and `t14`, and Darwin `escapeTime = 10`, the `.tmux.conf` shim, and helpers on `macm5`. A t14 resolution MAY address a proven Omarchy conflict but MUST NOT replace the shared TPM declaration.

#### Scenario: Linux behavior remains platform-specific [rog, thinkcentre, t14]

- GIVEN a scoped Linux host evaluates its Home Manager configuration
- WHEN tmux options are resolved
- THEN its escape time is zero
- AND its Linux-only integration remains available.

#### Scenario: Darwin behavior remains platform-specific [macm5]

- GIVEN macm5 evaluates its Home Manager configuration
- WHEN tmux options and managed files are resolved
- THEN its escape time is ten
- AND the `.tmux.conf` shim and Darwin-only helpers remain available.

### Requirement: Clone-Only TPM Activation

The system MUST provide a `home.activation` entry after `linkGeneration`. Home Manager MUST clone TPM only when a valid checkout is absent and MUST reuse a valid checkout and its mutable plugin state without deletion or recloning. It MUST NOT invoke TPM `bin/install_plugins` or install plugins during activation. Activation MUST succeed noninteractively without a terminal or configured tmux server when the checkout operation succeeds.

#### Scenario: First noninteractive activation clones TPM only [rog, thinkcentre, t14, macm5]

- GIVEN TPM is absent, its repository is reachable, and activation has no usable terminal
- WHEN Home Manager activates the generation after `linkGeneration`
- THEN it creates the TPM checkout without starting or configuring a tmux server
- AND it does not invoke `bin/install_plugins`.

#### Scenario: Repeated activation preserves mutable TPM state [rog, thinkcentre, t14, macm5]

- GIVEN TPM has a valid checkout and mutable installed plugin state
- WHEN Home Manager activates the generation in a noninteractive environment
- THEN it reuses that checkout and state without deleting, recloning, or installing plugins
- AND activation succeeds without a terminal-dependent TPM action.

### Requirement: Interactive TPM Plugin Installation

The system MUST leave TPM plugin installation to the user. After Home Manager clones TPM, a user in a tmux session loaded with the managed configuration MUST be able to press `prefix + I` to install the declared plugins. The system MUST preserve TPM's mutable Git-managed lifecycle and MUST NOT replace it declaratively.

#### Scenario: User installs plugins from a configured tmux session [rog, thinkcentre, t14, macm5]

- GIVEN TPM is cloned and a tmux session has loaded the managed configuration
- WHEN the user presses `prefix + I` in that session
- THEN TPM installs the declared plugins through its interactive binding
- AND Home Manager activation is not involved in the installation.

#### Scenario: Pre-existing tmux server is reloaded before installation [rog, thinkcentre, t14, macm5]

- GIVEN a running tmux server predates the managed configuration
- WHEN the user reloads the managed configuration and presses `prefix + I` in a session
- THEN the TPM binding is available for plugin installation
- AND existing tmux sessions remain under user control.
