# Design: mact2 OpenAI Transport Proxy via rog

## Technical Approach

Replace the incorrect application-layer gateway with a private HTTP CONNECT path:
`mact2` keeps OpenCode's built-in `openai` provider and `openai-medium` tier; its
OpenCode shell environment sends HTTP(S) through `rog`'s WireGuard address.
`rog` uses the stock `services.tinyproxy` module, not custom Python. OAuth stays
client-side on mact2; headless device login is the normal bootstrap, while an
age-encrypted seed is a one-use fallback.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| Runtime boundary | `services.tinyproxy` on `10.13.13.1:3128`, `Allow 10.13.13.3`, `ConnectPort 443` | Python API gateway; public nginx reverse proxy | A stock CONNECT proxy preserves OpenCode's native OAuth/provider behavior and is reachable only through the authenticated WireGuard peer. |
| Proxy authentication | WireGuard peer plus tinyproxy source allowlist; no Basic-auth secret | Reuse gateway client key; add Basic auth | `mact2` is the sole permitted peer and the listener is not public. Tinyproxy configuration is declarative, so embedding a password would widen secret exposure; this also fully retires gateway-key plumbing. |
| Auth bootstrap | Headless `opencode auth login` on mact2 is preferred; encrypted seed is fallback | Shared live `auth.json` as normal operation | An independent login prevents refresh-token-rotation contention. The fallback only seeds `openai`, then must not be concurrently used with rog's copied credential. |

### Nix module interface

`hosts/rog/default.nix` will configure the verified module interface:

```nix
services.tinyproxy = {
  enable = true;
  settings = {
    Listen = "10.13.13.1";
    Port = 3128;
    Allow = [ "10.13.13.3" ];
    ConnectPort = [ 443 ];
  };
};
```

`hosts/mact2/default.nix` sets `home.opencode.activeProviderName =
"openai-medium"` and appends `HTTP_PROXY`, `HTTPS_PROXY`, and
`NO_PROXY=localhost,127.0.0.1` through `home.opencode.extraInitContent`. This
is scoped to the mact2 OpenCode shell, not macOS globally.

## Data Flow and Secret Boundaries

```text
mact2 OpenCode (built-in openai OAuth) -- HTTPS_PROXY --> WG 10.13.13.1:3128
                                                        tinyproxy --> OpenAI HTTPS
headless login: mact2 <------------------------------------------> OpenAI OAuth
fallback: rog auth.json/openai -- age(mact2 public key) --> uploads ciphertext
          mact2 installer -- decrypt locally --> mact2 auth.json/openai
```

No OpenAI Platform `sk-` key, custom provider key, or public API endpoint
exists after apply. `auth.json` plaintext remains local to its host (mode 0600).
The upload is age ciphertext addressed only to mact2; it is safe to serve but
must never be replaced by plaintext. The publisher reads only rog's local
`openai` entry, validates it, encrypts to the existing mact2 recipient, and
atomically writes the ciphertext. The installer backs up `auth.json`, validates
the decrypted object, and overwrites only its `openai` entry while preserving
other providers.

## File Changes

| File | Action | Description |
|---|---|---|
| `linux/system/services/web/opencode-proxy.nix` | Delete | Retire Python API gateway. |
| `linux/system/services/web/nginx.nix` | Modify | Remove `oai.glats.org`; retain `/uploads/`. |
| `hosts/rog/default.nix` | Modify | Remove gateway import/config/timeout; add tinyproxy. |
| `hosts/rog/secrets.nix`, `shared/sops.nix`, `.sops.yaml`, `secrets/host/rog/openai-proxy.yaml` | Modify/Delete | Remove upstream/client gateway secrets and mact2 decryption rule. |
| `shared/opencode/providers-base.nix`, `shared/opencode.nix`, `hosts/mact2/default.nix` | Modify | Remove proxy provider/tier/export; select native tier and proxy environment. |
| `bin/install-opencode-auth-seed` | Modify | Require and overwrite only the `openai` object. |
| `bin/publish-opencode-auth-seed` | Create | Validate, age-encrypt, and atomically publish fallback seed. |

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Static | Nix options and retired references | `format-nix`; `nix flake check --no-build`; grep generated config/source for no `openai-proxy`, `oai.glats.org`, or gateway key export. |
| Integration | Private CONNECT path | Build/switch rog, verify listener is only `10.13.13.1`, reject non-mact2 source, and CONNECT from mact2 to OpenAI on 443. |
| E2E | Native auth and fallback safety | Run headless OpenCode login and a Codex request from mact2; test seed dry-run/install, backup, invalid ciphertext/JSON rejection, and `openai` overwrite. |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A — no executable classification | None | None |
| Git repository selection | N/A — no VCS command | None | None |
| Commit state | N/A — no commit automation | None | None |
| Push state | N/A — no push automation | None | None |
| PR commands | N/A — no PR automation | None | None |

## Migration / Rollout

1. Deploy tinyproxy on rog while the old gateway still exists; prove WireGuard
   CONNECT and rog egress.
2. Deploy mact2 native-tier/proxy environment. Use headless login to create an
   independent credential; use the encrypted seed only if login cannot complete.
3. Verify a real OpenCode request and refresh path. Then, in the same apply
   change, delete all gateway artifacts and secrets listed above.

No immediate restore is needed before planning: the current broken configuration
is the precise removal target, and reverting it before the replacement is proven
would return mact2 to its known blocked direct egress path.

## Rollback

Before cleanup is verified, roll mact2 back to the prior Nix generation and
disable tinyproxy to restore the temporary gateway path. After cleanup, disable
the proxy environment and tinyproxy, retain the native provider/auth backups,
and diagnose direct/proxy reachability; do not recreate or publish gateway
secrets. A prior system generation remains an emergency-only bridge, not the
target architecture.

## Open Questions

- [ ] Confirm mact2-to-rog CONNECT and headless device login after deployment; CDN behavior may require relaxing only the destination policy, never the WireGuard bind/source restriction.
