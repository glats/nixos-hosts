# mact2-openai-native-auth Specification

## Purpose

Authenticate OpenCode on `mact2` with native ChatGPT OAuth over the full-tunnel default.

## Requirements

### Requirement: Headless Native OAuth Bootstrap

`mact2` MUST bootstrap native OpenAI authentication with the headless device flow after the full tunnel is healthy. The flow MUST use `auth.openai.com` for device authorization and token exchange and MUST NOT use a Platform API key, custom base URL, or gateway credential.

#### Scenario: Complete device login [hosts: mact2]

- GIVEN the tunnel and device-flow browser are available
- WHEN the operator completes the device authorization and OpenCode exchanges its code
- THEN native OAuth credentials are stored for OpenCode
- AND all OAuth requests traverse the active full-tunnel route

### Requirement: Native Provider Activation

After home authentication proof, `mact2` MUST select the existing native `openai-medium` tier rather than any `openai-*-proxy` tier. Native Codex runtime traffic to `chatgpt.com` MUST use the active full-tunnel route.

#### Scenario: Run the native smoke test [hosts: mact2]

- GIVEN native OAuth is valid and the native tier is selected
- WHEN `opencode run -m openai/gpt-5.4 "PONG"` runs on the home network
- THEN the request succeeds through native OAuth
- AND its OpenAI runtime target traverses the full tunnel

### Requirement: Refresh-Path Continuity and Single Bootstrap Owner

The tunnel MUST preserve `auth.openai.com/oauth/token` refresh traffic. Only one bootstrap owner MAY modify native OAuth state at a time; concurrent refresh-token replacement MUST fail without overwriting a newer valid credential.

#### Scenario: Preserve a concurrent credential [hosts: mact2]

- GIVEN one authorized bootstrap is updating OAuth state and another attempts replacement
- WHEN the second operation detects changed auth state
- THEN it stops without writing its token
- AND the first valid credential remains usable for refresh

### Requirement: Auth-Seed Fallback Safety

`bin/install-opencode-auth-seed` MAY be used only as a one-shot fallback when device flow cannot complete. It MUST back up existing auth, merge only native OAuth data, reject API-key-like content or unsafe merges, and leave the existing auth untouched on failure.

#### Scenario: Reject an unsafe seed [hosts: mact2]

- GIVEN the fallback seed is invalid, API-key-like, or conflicts with current auth
- WHEN seed installation is attempted
- THEN installation fails without replacing current auth
- AND the pre-existing auth backup remains available

### Requirement: In-building native OAuth proof (OFFICE GATE)

Gateway retirement MUST wait for an office-network proof that both the Codex request and OAuth refresh succeed over the tunnel while the security agents remain healthy.

#### Scenario: Prove office native path [hosts: mact2]

- GIVEN `mact2` is in the office with native OAuth already bootstrapped
- WHEN a Codex request and `auth.openai.com/oauth/token` refresh are exercised
- THEN both succeed through the tunnel
- AND no security agent blocks the root daemon or the requests
