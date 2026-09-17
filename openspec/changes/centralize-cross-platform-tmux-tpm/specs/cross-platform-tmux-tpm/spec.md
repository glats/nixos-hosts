# Cross-Platform tmux TPM Specification

## Purpose

Provide one TPM declaration and safe Home Manager activation contract for scoped Linux and Darwin hosts while retaining their platform-specific tmux behavior.

## Requirements

### Requirement: Central TPM Runtime Declaration

The system MUST declare the TPM runtime exactly once in shared Home Manager configuration. That declaration MUST contain, in order, `tmux-plugins/tpm`, `tmux-plugins/tmux-resurrect`, `tmux-plugins/tmux-continuum`, `tmux-plugins/tmux-sessionist`, `tmux-plugins/tmux-yank`, `tmux-plugins/tmux-open`, and `christoomey/vim-tmux-navigator`. It MUST set `TMUX_PLUGIN_MANAGER_PATH` and place the TPM loader after every TPM declaration and other shared tmux configuration. TPM repositories MUST NOT be supplied through `programs.tmux.plugins`.

#### Scenario: Scoped hosts receive the canonical plugin set [rog, thinkcentre, t14, macm5]

- GIVEN a scoped host evaluates its Home Manager tmux configuration
- WHEN the generated tmux configuration is inspected
- THEN it contains the seven declared repositories exactly once in the specified order
- AND its final TPM-related command is the TPM loader.

#### Scenario: Platform modules do not create competing plugin managers [rog, thinkcentre, t14, macm5]

- GIVEN Linux and Darwin platform tmux modules are composed with the shared module
- WHEN their effective tmux options are evaluated
- THEN no TPM repository is interpreted as a `programs.tmux.plugins` package value.

### Requirement: Platform tmux Compatibility

The system MUST preserve `escapeTime = 0` and Linux-only tmux integration on `rog`, `thinkcentre`, and `t14`. It MUST preserve `escapeTime = 10`, the `.tmux.conf` compatibility shim, and Darwin-only helpers on `macm5`. A t14-specific resolution MAY override only a proven Omarchy conflict and MUST NOT replace the shared TPM declaration.

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

### Requirement: Idempotent TPM Activation

The system MUST provide one valid `home.activation` DAG entry that runs after `linkGeneration`. On activation, it MUST create or bootstrap TPM only when a valid TPM clone is absent, MUST reuse an existing valid clone and plugin runtime state, and SHOULD invoke the TPM installer when available. Repeated activation MUST NOT require deletion or recloning of a valid TPM checkout.

#### Scenario: First activation bootstraps TPM [rog, thinkcentre, t14, macm5]

- GIVEN TPM is absent and activation can reach its repository
- WHEN Home Manager activates the generation
- THEN the shared activation entry creates TPM after `linkGeneration`
- AND invokes the available plugin installer.

#### Scenario: Repeated activation preserves valid TPM state [rog, thinkcentre, t14, macm5]

- GIVEN TPM already has a valid checkout and installed plugins
- WHEN Home Manager activates the same generation again
- THEN activation reuses that checkout without deleting or recloning it
- AND installation remains safe to repeat.
