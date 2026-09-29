# OpenCode Warden Opt-In Specification

## Purpose

Make the `opencode-warden@1.2.0` npm plugin available offline as an explicit opt-in, disabled by default, so Warden's redaction and deterministic path protection no longer load on every OpenCode host unless a host opts in. Nix `permissions` remains the authorization boundary.

## Requirements

### Requirement: Default-Off Warden Option

The system MUST declare `home.opencode.plugins.warden.enable` as a boolean option with a default value of `false`. The two base npm plugins MUST remain part of `npmPlugins` regardless of this flag.

#### Scenario: Option defaults off

- GIVEN a Home Manager configuration leaves `home.opencode.plugins.warden.enable` unset [rog, thinkcentre, t14, macm5]
- WHEN the configuration is evaluated
- THEN the option resolves to `false`

### Requirement: V1 Warden Omission When Disabled

When the flag resolves to `false`, the generated V1 `opencode.json` MUST NOT contain `opencode-warden@1.2.0` in its `plugin` array, and it SHALL contain only `opencode-claude-auth@latest` and `opencode-multimodal@latest`.

#### Scenario: Default V1 omits Warden

- GIVEN `warden.enable = false` on a supported host
- WHEN the V1 `opencode.json` is generated [rog, thinkcentre, t14, macm5]
- THEN the `plugin` array omits `opencode-warden@1.2.0`
- AND contains `opencode-claude-auth@latest` and `opencode-multimodal@latest`

### Requirement: V1 Warden Inclusion When Enabled

When the flag resolves to `true`, the generated V1 `opencode.json` MUST contain exactly one `opencode-warden@1.2.0` entry in its `plugin` array, in addition to the base plugins.

#### Scenario: Opt-in adds Warden once

- GIVEN `warden.enable = true` on a supported host
- WHEN the V1 `opencode.json` is generated [t14]
- THEN the `plugin` array contains `opencode-warden@1.2.0` exactly once
- AND the base plugins remain present

### Requirement: Conditional Warden Config File

The `opencode-warden.json` managed file MUST be written only when the flag resolves to `true`, carrying the existing `audit.filePath`. When a later generation disables the flag, Home Manager SHALL remove that file.

#### Scenario: Config written only when enabled

- GIVEN `warden.enable = true`
- WHEN the Home Manager generation activates
- THEN `~/.config/opencode/opencode-warden.json` exists with `audit.filePath`

#### Scenario: Disabled generation removes stale config

- GIVEN a prior generation wrote `opencode-warden.json` and the flag is now `false`
- WHEN the disabled generation activates
- THEN the formerly managed `opencode-warden.json` is removed

### Requirement: Other Plugins Unaffected

The change MUST NOT alter the `activePlugins` attrset or any npm plugin other than Warden. Warden SHALL NOT be added to `activePlugins`, which is reserved for managed `.ts` plugins.

#### Scenario: Managed plugins untouched

- GIVEN an existing OpenCode configuration
- WHEN the opt-in option is enabled or disabled [rog, thinkcentre, t14, macm5]
- THEN `activePlugins` membership is unchanged
- AND no non-Warden npm plugin changes

### Requirement: V2 Stability

The V2 `opencode.json` MUST remain byte-stable: it SHALL NOT emit Warden and SHALL preserve its V1 drop set.

#### Scenario: V2 output unchanged

- GIVEN the V2 runtime serializer and drop set
- WHEN the opt-in option is enabled or disabled [t14]
- THEN the generated V2 `opencode.json` is unchanged

### Requirement: Offline Package Pin Retention

`opencode-warden@1.2.0` MUST remain pinned with its fixed-output hash in `pkgs/opencode-npm-packages` so the opt-in path resolves offline without runtime npm access.

#### Scenario: Opt-in resolves offline

- GIVEN `warden.enable = true`
- WHEN OpenCode loads the plugin [rog, thinkcentre, t14, macm5]
- THEN `opencode-warden@1.2.0` is available from the pinned package
- AND no npm network resolution is required

### Requirement: Cross-Platform Evaluation

The change MUST pass `nix flake check --no-build` and evaluate activation packages for all four hosts; an explicit consumer override of `npmPlugins` SHALL take precedence over the derived default.

#### Scenario: Flake check and host evaluation pass

- GIVEN the modified `plugins.nix` and `opencode.nix`
- WHEN the evaluation suite runs [rog, thinkcentre, t14, macm5]
- THEN `nix flake check --no-build` passes
- AND all four activation targets evaluate