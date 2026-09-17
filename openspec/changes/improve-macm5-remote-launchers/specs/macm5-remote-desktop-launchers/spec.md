# macm5 Remote Desktop Launchers Specification

## Purpose

Provide recognizable, self-contained macm5 remote-desktop application bundles without changing their connection behavior.

## Requirements

### Requirement: Friendly Bundle Presentation

The macm5 configuration MUST deploy exactly four remote-desktop bundles in `~/Applications`: `Remote T14.app`, `Remote oneplus.app`, `Remote Rog.app`, and `Remote ThinkCentre.app`. Each bundle's user-visible name metadata MUST match its directory name without `.app` and MUST NOT contain hyphens.

#### Scenario: macm5 deploys all friendly bundles

- GIVEN macm5 activates its Home Manager configuration
- WHEN deployment completes
- THEN `~/Applications` contains the four exact friendly bundle names
- AND each bundle metadata name matches its friendly name [Host: macm5]

#### Scenario: friendly names remain human-readable

- GIVEN the four deployed bundles are inspected
- WHEN their directory and visible plist names are read
- THEN none uses a technical or hyphenated launcher name [Host: macm5]

### Requirement: Bundle-Local Network Icon

Each friendly bundle MUST contain a readable native macOS generic network `.icns` resource within its own resources directory, and its metadata MUST reference that local resource. The activation MUST validate the native icon source before deployment and MUST NOT substitute custom artwork, icon-conversion tooling, or a repository-managed icon asset.

#### Scenario: deployed bundles reference readable local icons

- GIVEN macm5 has completed launcher deployment
- WHEN every friendly bundle's icon metadata and resources are inspected
- THEN each reference resolves to a readable `.icns` inside that same bundle [Host: macm5]

#### Scenario: native icon source is unavailable

- GIVEN macm5 cannot read the approved native generic network icon source
- WHEN launcher deployment is attempted
- THEN deployment fails safely rather than installing an iconless or substituted bundle [Host: macm5]

### Requirement: Connection Behavior Preservation

The four launchers MUST preserve their existing protocol, viewer, host, port, executable, bundle identifier, and launch arguments. Opening a friendly bundle MUST invoke the same configured remote-desktop client behavior as its corresponding technical-name predecessor.

#### Scenario: launcher connection definitions are unchanged

- GIVEN the pre-change and proposed launcher definitions for T14, oneplus, Rog, and ThinkCentre
- WHEN their connection fields are compared
- THEN all protocol and invocation fields are identical [Host: macm5]

#### Scenario: macm5 launches each friendly application

- GIVEN the four friendly bundles are registered on macm5
- WHEN each bundle is opened
- THEN its configured remote-desktop client is invoked without bundle-resolution failure [Host: macm5]

### Requirement: Safe Legacy Bundle Migration

Activation MUST remove only `remote-t14-tigervnc.app`, `remote-oneplus5.app`, `remote-rog.app`, and `remote-thinkcentre.app` from `~/Applications` after replacing them with their corresponding friendly bundles. The migration MUST be idempotent and MUST NOT remove unrelated applications.

#### Scenario: activation removes the enumerated legacy bundles

- GIVEN all four legacy technical bundles exist in `~/Applications`
- WHEN macm5 activates the updated configuration
- THEN only those four legacy bundle paths are absent and all friendly replacements exist [Host: macm5]

#### Scenario: repeated activation preserves unrelated applications

- GIVEN the friendly bundles and an unrelated application exist in `~/Applications`
- WHEN macm5 activates the updated configuration again
- THEN the friendly and unrelated applications remain present [Host: macm5]

### Requirement: Platform-Appropriate Verification

Verification MUST distinguish configuration evaluation from native macm5 behavior. Non-macm5 environments MAY validate the macm5 Darwin configuration, but Finder, Spotlight, native icon, signing, registration, and launch verification MUST run on macm5.

#### Scenario: non-macm5 validation remains scoped

- GIVEN validation runs on a non-macm5 host
- WHEN the Darwin configuration is evaluated
- THEN the result is recorded as configuration-only evidence [Host: non-macm5]

#### Scenario: macm5 validates native presentation and registration

- GIVEN macm5 has activated the configuration
- WHEN Finder, Spotlight, bundle resources, and application registration are checked
- THEN all four friendly launchers are discoverable with their local network icons [Host: macm5]
