# Design: Port OpenCode V2 Provider Allowlist

## Technical Approach

Make `shared/opencode/providers-base.nix` the sole provider-surface authority. It will expose the ordered six-ID allowlist (`opencode`, `opencode-go`, `anthropic`, `openai`, `github-copilot`, `nvidia`) and a V1 curated catalog deny set derived by filtering a local catalog-provider set against that list. `runtime-config.nix` consumes those derived values: V1 serializes the deny set, while V2 serializes an ordered `experimental.policies` sequence: deny `provider.use` for `*`, then allow each ID in list order.

Credential reduction is independent of provider routing: create and register the Linux-only dictation module before removing the existing Groq export from the shared OpenCode shell initialization. Keep encrypted secrets unchanged.

## Architecture Decisions

| Decision | Alternatives | Rationale |
|---|---|---|
| Provider base exports the allowlist and derived V1 deny set | Duplicate V1/V2 lists; retain profile-owned deny list | One Nix source prevents runtime drift while retaining V1's curated catalog semantics. |
| Remove `home.opencode.disabledProviders` and its profile assignment | Leave a writable override | It has one consumer and would reintroduce a second provider-surface authority. Runtime config reads the provider-base contract directly. |
| V2 policy is deny-first, then ordered allows | V2 `providers` declarations; allow-only policies | Catalog declarations are additive; V2 policy ordering is the supported provider-level exclusion mechanism. |
| Preserve NVIDIA unchanged | Remove/fix/port NVIDIA to V2 | The dormant provider, profile, `allProviders`, and `NVIDIA_API_KEY` are explicitly retained; V2 porting is out of scope. |
| Re-home Groq first | Delete its shared export immediately | Dictation remains the sole Linux consumer without exposing Groq to OpenCode or Darwin shells. |

## Data Flow

    providers-base.nix
      allowlist ──> filtered V1 catalog deny set ──> V1 disabled_providers
          └───────> deny * + ordered allows ──────> V2 experimental.policies

    sops opencode/groq_api_key ──> linux/home/groq-dictation.nix ──> Linux dictation shell
    shared/opencode.nix ──> OPENCODE_API_KEY + NVIDIA_API_KEY only

V2 may list only the five catalog-backed allowed providers: `nvidia` remains permitted but cannot appear until its existing custom declaration is ported to V2. The smoke therefore proves that every listed provider belongs to the six-ID set, rather than requiring NVIDIA to appear.

## File Changes

| File | Action | Description |
|---|---|---|
| `shared/opencode/providers-base.nix` | Modify | Add the canonical ordered allowlist, the curated catalog set, and derived V1 disabled-provider output; leave NVIDIA declarations and profiles byte-identical. |
| `shared/opencode/runtime-config.nix` | Modify | Read provider-base outputs; emit V1 `disabled_providers` and V2 deny-then-allow policies. |
| `shared/opencode.nix` | Modify | Remove the obsolete disabled-provider option and all exports except OpenCode Go and NVIDIA. |
| `shared/opencode-profile.nix` | Modify | Remove the former hard-coded disabled-provider assignment. |
| `linux/home/groq-dictation.nix` | Create | Linux-only, sops-backed `GROQ_API_KEY` zsh export owned by dictation. |
| `linux/home/shared-modules.nix` | Modify | Register the dictation module before the shared OpenCode export is removed. |

## Interfaces / Contracts

`providers-base.nix` returns `providerAllowlist` (ordered list) and `disabledProviders` (derived V1 catalog deny list). `runtime-config.nix` is their only consumer. `home.opencode.disabledProviders` is removed; host configuration must not supply it. The Groq secret path remains `opencode/groq_api_key`; no `.sops.yaml` or secret payload changes occur.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Evaluation | JSON shape, order, and NVIDIA preservation | Evaluate each relevant Home Manager target; inspect generated V1/V2 JSON; diff preserved NVIDIA blocks against baseline. |
| Static regression | Credential ownership | Confirm OpenCode init exports exactly OpenCode Go/NVIDIA; confirm dictation exports Groq and registration exists; confirm ten exports have no consumers. |
| Runtime | Experimental V2 enforcement on rog | After activation, run `opencode2 models` and assert no provider outside the allowlist; run `opencode2 run -m groq/<known-model> "hi"` and require rejection. This is the empirical deny gate. |
| Integration | Repository configuration | Format touched Nix files, run `nix flake check --no-build`, and evaluate Linux plus both macm5 Home Manager paths. |

## Threat Matrix

| Boundary | Applicability | Design response / RED tests |
|---|---|---|
| Documentation-like paths | N/A — no file classification or execution changes | None. |
| Git repository selection | N/A — no Git command changes | None. |
| Commit state | N/A — no commit automation | None. |
| Push state | N/A — no push automation | None. |
| PR commands | N/A — no PR automation | None. |

The relevant boundary is provider routing; the V2 deny smoke above is its required failure proof. The Groq re-home only changes declarative shell initialization and introduces no executable command path.

## Migration / Rollout

Land `groq-dictation.nix` and its shared-module registration before or atomically with removal from `shared/opencode.nix`. Activate/evaluate first, then run the rog smoke. Roll back by reverting the touched Nix files; secrets stay intact.

## Open Questions

- [ ] The spec says V2 models lists “only the six” providers, but current V2 has no NVIDIA declaration. Confirm the intended assertion is “no provider outside the six” until a separate NVIDIA V2 port.
