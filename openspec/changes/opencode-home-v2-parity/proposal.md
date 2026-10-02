# Proposal: OpenCode V2 Scoped Home Launcher Parity

## Intent

Restore `opencode-home` behavior for V2 on `macm5`. Confirmed handoff revision 2 accepts V2 stability and preserves scoped proxy steering, superseding exploration's proxy-necessity prerequisite.

## Scope

### In Scope
- Probe `127.0.0.1:2080` with bounded readiness checking; set process-scoped `HTTP_PROXY`/`HTTPS_PROXY=http://127.0.0.1:2080` only when listening.
- Otherwise print a stderr notice and launch without adding proxy variables.
- Execute the actual V2 binary with existing V2 isolation environment and unchanged argument forwarding; retain MCP proxy hygiene.
- Preserve current V1 behavior and other hosts; document the V2 scoped launch path.

### Out of Scope
- General migration/cutover, stability audits, provider/model/agent/SDD changes.
- Network/tunnel redesign, deployment, or implementation in this phase.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `macm5-openai-tls-tunnel`: extend **Proxy-Environment and MCP Isolation** to an explicit V2 scoped-launch path, preserving V1 scenarios and correcting the obsolete `bin/opencode-home` reference to the packaged Go launcher. Other tunnel requirements remain unchanged.

`opencode-runtime-proxy` remains unchanged: no gateway or provider changes.

## Approach

Reuse the Go launcher; introduce no shell operational binary. Wire a V2-targeted invocation through Home Manager, sourcing the existing V2 environment and using `${pkgs.opencode-v2}/bin/opencode2`, not shell-function lookup. Keep default V1 targeting and declarative local-MCP scrubbing intact; never export proxies globally.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `pkgs/nixos-scripts/cmd/opencode-home/main.go` | Modified | Reusable V2 target and focused launcher tests |
| `shared/shell-aliases.nix` | Modified | V2 scoped invocation using existing isolation |
| `shared/opencode/runtime-config.nix` | Preserved | MCP scrub regression checks |
| `docs/home-link.md` | Modified | V2 invocation and fallback instructions |
| `openspec/specs/macm5-openai-tls-tunnel/spec.md` | Delta planned | V2 scoped-launch contract |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Wrong executable or isolation leakage | Medium | Assert executable, environment, arguments, and parent isolation |
| MCP proxy inheritance | Medium | Generated-config and child-environment checks |
| Readiness mistaken for tunnel health | Medium | Treat probe as listener-only, not connectivity proof |

## Rollback Plan

Revert launcher, wiring, and associated documentation changes; restore the prior macm5 generation if later activated. Preserve V1, V2 data/authentication, tunnel configuration, and unrelated dirty files.

## Dependencies

Existing packaged V2 executable, generated V2 environment, Go launcher, and loopback inbound.

## Success Criteria

- [ ] Tests cover listener up/down, notice, conditional proxy, executable identity, exact arguments, V2 isolation, and unchanged parent/V1 behavior.
- [ ] Local MCP scrub remains effective; remote MCP definitions remain untouched.
- [ ] Go suite, shared flake check, macm5 Darwin/Home Manager evaluations, and affected Linux Home Manager evaluations pass.
- [ ] Later macm5 inspection confirms V2/MCP environments. No runtime tests are claimed here.
