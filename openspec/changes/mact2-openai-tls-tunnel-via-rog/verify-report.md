```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:5f63d8622d6d7902388df372a43c8dec7e86d33b8ad8b40c7ccacc2771207705
verdict: fail
blockers: 1
critical_findings: 1
requirements: 8/19
scenarios: 8/24
test_command: "format-nix --check && nix flake check --no-build"
test_exit_code: 0
test_output_hash: sha256:e4faaf4be736a894ad51c03f2f6edfd465952b7b6fbd427dfad34ccec747d201
build_command: "nix build .#nixosConfigurations.rog.pkgs.nixos-scripts --no-link --print-out-paths"
build_exit_code: 0
build_output_hash: sha256:3e537811a127207a907e61c92146a2b9330724bc993dfd7a44f2e541bd762523
```

# Verification Report: mact2-openai-tls-tunnel-via-rog

**Revision:** cb7159ece79812804c6d1cbc06605018897fd9ea on both deployed hosts  
**Mode:** Standard verification; read-only runtime probes  
**Time:** 2026-08-28

## Build and test evidence

| Check | Result | Evidence |
|---|---|---|
| Formatting and Linux flake evaluation | PASS | format-nix --check and nix flake check --no-build exited 0; Darwin was omitted as incompatible on this Linux evaluator. |
| Existing scripts derivation | PASS | nix build .#nixosConfigurations.rog.pkgs.nixos-scripts --no-link --print-out-paths exited 0. |
| Android config shape | PASS | bash -n bin/tunnel-device-link; fake-UUID --config piped to sing-box 1.13 check exited 0. |

## Requirement verdicts

| Spec requirement | Verdict | Evidence |
|---|---|---|
| TLS tunnel endpoint and cover page | FAIL-KNOWN | sing-box active, 127.0.0.1:4011 listening, and cover returned 200; WS path without Upgrade returned a sing-box error body, not the cover page. |
| Per-device VLESS authentication and secret safety | PASS | Current rog log has [mact2]; four [phone] www.gstatic.com:443 handshakes occurred today. Existing runtime secret permissions remain documented as 0400. |
| Root-managed full-tunnel routing | DEFERRED | mact2 daemon running, utun4 is 172.19.0.1/30, IP echo is 201.188.187.112; scoped flip was not performed because it needs a rebuild. |
| Self-loop prevention | PASS | mact2 tunnel is active and https://tun.glats.org/ remains reachable; declared direct resolver and auto-detect-interface attrs evaluate. |
| Proxy environment and MCP isolation | NOT-RUNNABLE | Generated local MCP entries contain empty proxy variables and NO_PROXY=*; no live MCP children existed for ps eww, and launcher-down behavior was not disrupted. |
| Stealth client TLS | DEFERRED | Source and generated-system attrs declare uTLS chrome; rendered root-only config and outer ClientHello capture require sudo or office procedure. |
| Home transport proof | PASS | Direct and loopback-proxy mact2 requests to auth.openai.com both showed issuer O=Google Trust Services; CN=WE1. |
| In-building coexistence | OFFICE-PENDING | Requires mact2 in the office with FortiClient, Netskope, CrowdStrike, and long-lived WS evidence. |
| Declarative teardown | DEFERRED | No bootout or revert was performed because VERIFY is read-only; documented launchctl procedure exists. |
| Headless native OAuth bootstrap | PASS | auth.json has an openai entry with keys access, accountId, expires, refresh, type; expiry check is true without printing values. |
| Native provider activation | PASS | Provider evaluates to openai-medium; rog has current [mact2] connections to chatgpt.com and auth.openai.com. |
| Refresh-path continuity and bootstrap ownership | DEFERRED | Valid unexpired credential is present, but no forced refresh or concurrent-write test was run. |
| Auth-seed fallback safety | NOT-RUNNABLE | Unsafe-seed exercise would require controlled auth-state mutation and was not run under read-only constraints. |
| In-building native OAuth proof | OFFICE-PENDING | Requires the office network and security agents. |
| Declarative device credential lifecycle | DEFERRED | Phone connectivity is evidenced, but revoke/rebuild/restore was deliberately not performed. |
| Runtime-only Android link delivery | PASS | Script syntax and generated fake-secret SFA config pass sing-box validation; repo and packaged store scripts are executable. |
| mact2 runtime provider transition | PASS | Native provider is selected, no proxy-tier Nix references remain, and current OpenAI destinations appear in rog logs. |
| Gated gateway availability and retirement baseline | PASS | openai-proxy, OPENAI_PROXY_API_KEY, and oai.glats.org have zero Nix matches, matching the superseding retired-gateway baseline. |
| Scoped rollback | DEFERRED | No rollback was executed in this verification-only run. |

## Verification matrix summary

| Verdict | Requirements |
|---|---:|
| PASS | 8 |
| FAIL-KNOWN | 1 |
| DEFERRED | 6 |
| OFFICE-PENDING | 2 |
| NOT-RUNNABLE | 2 |
| Total | 19 |

**Scenario coverage:** 8/24 runtime-compliant scenarios. Deferred, office-only, and read-only-prohibited exercises are not counted as compliant.

## SUDO-DEFERRED checks

- Rendered mact2 config: sudo sing-box check -c /run/secrets/rendered/sing-box-tunnel.json
- Inspect rendered client TLS/route shape: sudo jq {outbounds,route} /run/secrets/rendered/sing-box-tunnel.json
- Confirm runtime secret placement: sudo stat -f %Sp /run/secrets/rendered/sing-box-tunnel.json

## Failures

1. **Cover-page stealth (known from home evidence and reproduced):**
   ```text
   GET /ed59280aa562f4b7eba4519e3c316e24 without Upgrade -> 400
   body: handshake error: bad Upgrade header
   GET /not-a-tunnel-path -> 404
   ```
   This violates the requirement that non-tunnel paths, including a non-upgrade request to the WS path, provide cover-page behavior. No fix was made.

## Documentation spot-check

- bootout/bootstrap use the deployed /Library/LaunchDaemons/org.nixos.sing-box-tunnel.plist.
- The deployed plist label is org.nixos.sing-box-tunnel, matching the documented kickstart label.
- bin/tunnel-device-link and bin/opencode-tunnel exist in the repo and built nixos-scripts package.

## Final verdict

**HOME-VERIFIED WITH ONE KNOWN STEALTH FAILURE — OFFICE GATES PENDING.**

`tasks.md` was not changed: this run did not newly prove any currently unchecked task end-to-end.
