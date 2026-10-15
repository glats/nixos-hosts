# Exploration: Gentle AI v3 vs v4 — single-stack stability on OpenCode V2

## Scope

Choose **ONE** stable Gentle AI stack for the OpenCode V2 runtime across all four
hosts (rog, thinkcentre, t14 = Linux x86_64 NixOS; macm5 = aarch64-darwin), with
V1 retirement desired and **no indefinite dual install**. Prior v4 approval is
conditional on stability research; the SDD→ODD retirement is **already authorized
if stable**, so SDD removal is migration effort, not an automatic disqualifier.
Research only — no implementation, no activation, no bump. Time snapshot:
**2026-10-02**.

## Current state (verified in tree)

- `flake.nix` pins `gentle-ai-src` to the **v2.5.0** tag (`github:Gentleman-Programming/gentle-ai/v2.5.0`), comment "do not track main".
- OpenCode V2 is pinned to CLI **2.0.14** (`pkgs/opencode-v2/default.nix` → `@opencode/cli-{linux-x64,linux-arm64,darwin-x64,darwin-arm64}@2.0.14`) and `@opencode/plugin`/`schema`/`client` **2.0.14** (`pkgs/opencode-npm-packages-v2/versions.json`).
- The repo consumes Gentle AI **declaratively** (Nix derivations `pkgs/gentle-ai` + `pkgs/gentle-ai-assets`), not via the unmanaged `install`/`sync` pipeline. This distinction is load-bearing for the evidence matrix below.
- OpenCode V2 SDD support runs on **local vendored adapters** — `pkgs/gentle-ai-assets/v2-plugins/{opencode-review-transport.ts,sdd-task-result.ts,skill-registry.ts}` + `engram.ts` (engram-assets) — against `@opencode/plugin` 2.0.14, because upstream v2.5.0 ships no V2 plugins.
- Hosts: rog/thinkcentre/t14 = `x86_64-linux`; macm5 = `aarch64-darwin` (`flake.nix` nixosConfigurations/darwinConfigurations + `lib/mkHost.nix`/`mkDarwinHost.nix`).
- In-flight, must be preserved: `complete-opencode-v1-to-v2-migration`, `port-gentle-ai-sdd-to-opencode-v2`, `fix-opencode-v1-v2-credential-collision`, `opencode2` launcher/standalone/proxy parity, and all credentials/sessions.
- **Not claimed stable:** the current v2.5.0 setup has no multi-host/runtime proof, and the user has observed delegation failures on it (see #3796). No candidate is presumed stable; all three are measured below.

## External evidence (verified, 2026-10-02)

Latest exact patch releases:

| Line | Latest tag | Published | Age at snapshot |
|---|---|---|---|
| v3 | **v3.7.0** | 2026-09-23 | ~9 days |
| v4 | **v4.0.0** | 2026-10-01 | ~1 day |

SDD presence verified **at tag sources** (`internal/cli/`):

- `refs/tags/v3.7.0`: `sdd_archive_compose.go`, `sdd_attempt.go`, `sdd_preflight_hook.go`, `sdd_status.go`, `sdd_task_result.go` — **SDD subcommands present**.
- `refs/tags/v4.0.0`: only `sdd_retirement_collateral_test.go` — **SDD removed**; v4 adds `opencode_sdk_manager.go` and `review_opencode_v2_host_e2e_test.go` (native V2 review path).

Context7 docs (`/gentleman-programming/gentle-ai`) and the v4.0.0 release body confirm:
v4 retires SDD/OpenSpec; ODD is the only workflow; RDD sections ship only to
claude-code/codex/opencode; module path moves to `/v4`; provider contract stays
`1.2.0`.

### OpenCode V2 compatibility — the decisive upstream statements

From the v4.0.0 release body (and `docs/opencode-compatibility.md`):

- V2 native review is **proven only on OpenCode 2.0.19 on macOS, with a scripted loopback provider** — *not* proven with real reviewer models, other V2 releases, or other operating systems.
- Gentle AI's V2 SDK provisioning is **2.0.4** (isolated npm env). The repo pins **2.0.14** — a version mismatch to resolve regardless of path.
- v3.3.0 shipped OpenCode V2 as **"beta"** ("native V2 review remains unavailable"); its acceptance issue #3744 is still open.
- Known fail-closed follow-ups remain open in v4.0.0: relay-exit can drop a refusal reason; `authority_unavailable` misreported as `stale_authority`; `--dry-run` does not probe OpenCode.

## Evidence matrix (applicability, not raw counts)

An open issue is evidence of a defect on its **reported** version only; it does
not prove every tag is affected. Extrapolation to other tags/versions is marked
**unknown**. "Installer/sync-only" defects are unlikely to apply to the repo's
declarative Nix integration (which does not run `install`/`sync`); "runtime"
defects apply directly.

| # | Title | Class | Reported on | Direct applicability to repo | URL |
|---|---|---|---|---|---|
| 4984 | review refused `immutable_review_transport_unsupported` | runtime | gentle-ai 3.7.0, OpenCode 2.0.16 V2, **Linux x86_64** | **Direct** — review transport on Linux | issues/4984 |
| 5042 | `engram.ts` rejected by opencode 2.0.18 (expects `effect/setup`, gets `{id,server}`) | runtime | OpenCode 2.0.18 | **Direct** — repo `engram-v2.ts` plugin; 2.0.14→2.0.18 drift unknown | issues/5042 |
| 4795 | engram plugin adapter ships V1 shape, fails 2.x loader (no default export) | runtime | OpenCode 2.x | **Direct** — engram plugin loading | issues/4795 |
| 3796 | OpenCode task delegation interrupted without result | runtime | OpenCode, Linux | **Direct** — matches user-observed delegation failures | issues/3796 |
| 4030 | single-worktree reviewer wedged (lens-context OK, transport rejects) | runtime | gentle-ai 2.5.0, OpenCode 1.18.25 | **Direct** — affects current pin; V1 side though | issues/4030 |
| 4807 | `ResolveTarget` launcher fork-bomb via PATH wrapper (names `nix`) | launcher | internal/opencode/background.go:358 | **Partial** — repo owns its `opencode2` launcher; verify overlap only | issues/4807 |
| 4762 | renew managed opencode.json for 2.x strict-schema conformance | config | OpenCode 2.x | **Partial** — repo owns config emission via Home Manager; schema conformance still a real check | issues/4762 |
| 4940 | post-apply verification requires V2-skipped logo files → install never passes | installer/sync-only | V2, v3.x line | **Bypassed** by declarative asset integration | issues/4940 |
| 5066 | V2 community-plugin refusal = failed apply step → install rollback | installer/sync-only | OpenCode V2 | **Bypassed** by declarative integration | issues/5066 |
| 5184 | sync refuses newer `@opencode/plugin`, prescribes downgrade to 2.0.4 | installer/sync-only | 4.0.0 | **Bypassed**; but the 2.0.4-vs-2.0.14 SDK mismatch itself must be resolved declaratively | issues/5184 |
| 5185 | 3.x→4.0.0 sync refuses own previously-shipped review-transport as "unverified ownership" | installer/sync-only | 3.x→4.0.0 | **Bypassed**; repo vendors its own plugins | issues/5185 |
| 5099 | managed plugin recovery dead-ends | installer/sync-only | — | **Bypassed** by declarative integration | issues/5099 |
| 4796 | sync refuses when `opencode --version` exceeds 3s probe deadline | installer/sync-only | — | **Bypassed** by declarative integration | issues/4796 |
| 5182 | sync writes unbootable opencode.jsonc (`agents` + V2 permissions) | installer/sync-only + V1 | OpenCode **1.18.34**, gentle-ai 3.7.0 | **Out of scope** — V1 runtime is being retired; only relevant if the same defect reproduces on V2 (unverified) | issues/5182 |

Platform coverage: macOS is the only OS where upstream claims any V2 review proof
(2.0.19). Linux x86_64 — 3 of this repo's 4 hosts — has **no** upstream V2 proof
and has open runtime refusal/delegation bugs (#4984, #3796). NixOS is not in the
installer-supported distro list, but the repo's declarative Nix build is
independent of that installer and so is not blocked by it.

Distinction required by the brief: runtime defects (#4984, #5042, #4795, #3796,
#4030, #4807, #4762) are the ones that can block the repo regardless of how
assets are delivered. Installer/sync defects (#4940, #5066, #5184, #5185, #5099,
#4796) are delivery-mechanism issues the repo's declarative integration can route
around; they are not standalone disqualifiers.

## Approaches

### 1. Pin v4.0.0 (ODD only) as the single stack
- Pros: where upstream is investing V2 support; SDD→ODD migration already authorized if stable; native V2 plugin assets.
- Cons: 1-day-old; V2 review unproven off-macOS; `/v4` module path; SDK 2.0.4-vs-2.0.14 mismatch; the runtime gates below are unproven on this fleet.
- Effort: Medium-High (ODD migration scope, but rollback is possible: historical SDD artifacts are preserved and generation rollback is available).

### 2. Pin v3.7.0 (SDD + ODD) as the single stack
- Pros: SDD preserved (verified at tag); 9 days + patch history; avoids `/v4`.
- Cons: OpenCode V2 still "beta" (#3744 open); runtime gates below unproven on this fleet.
- Effort: Medium.

### 3. Keep v2.5.0 + local vendored V2 plugins (current path)
- Pros: preserves SDD; repo-controlled pins (v2.5.0 tag + `@opencode/plugin` 2.0.14); already partially built.
- Cons: not upstream-supported for V2; user-observed delegation failures and #4030 mean it is **not proven stable** either.
- Effort: Low-to-finish.

## Recommendation

**Defer the final v3-vs-v4 pin; do not crown any candidate stable yet.** All three
candidates lack multi-host/runtime proof, and the current v2.5.0 path already
shows delegation failures. The SDD→ODD decision is decoupled (authorized if
stable), so the discriminator is purely **whether the OpenCode V2 runtime —
plugins, delegation, review execution, MCP/Engram — actually works on this fleet
through the repo's declarative Nix integration**. That is unproven for v3 and v4
and not assumed for v2.5.0. Provisional lean is **v3.7.0** only because it keeps
SDD and avoids the `/v4` + SDK-mismatch churn; this is a scope preference, not a
stability finding.

### Gates before recommending the whole fleet (isolated, declarative, non-destructive)

Run on **one Linux x86_64 NixOS host (rog)** and smoke/remote on **aarch64-darwin
(macm5)**, in throwaway profiles that never touch production credentials/sessions
or the `opencode2` launcher/proxy state. Every gate is exercised through the
repo's **declarative Nix derivations** (`pkgs/gentle-ai`, `pkgs/gentle-ai-assets`,
Home-Manager-emitted config), never by invoking the unmanaged `install`/`sync`
pipeline. Any CLI flag used must first be source-verified against the pinned tag;
no command is prescribed here.

1. **Plugin boot.** All four vendored V2 plugins (sdd-task-result, opencode-review-transport, skill-registry, engram) load on the pinned OpenCode 2.0.14 with no API-shape/`default export` failure (gates #5042/#4795).
2. **MCP/Engram.** Engram MCP + plugin reachable in an isolated session (gates #4795-class loader issues).
3. **Delegation/result.** A real delegated task returns a verifiable result, repeated enough times to discriminate the #3796 interruption the user observed.
4. **Review execution.** A real native review round-trip **completes** with a supported provider on Linux — not just an eligibility/status probe (a green eligibility read cannot establish review works; #4984 shows eligibility refusing on Linux before execution).
5. **Platform smoke.** Linux x86_64 (rog) full pass + aarch64-darwin (macm5) smoke/remote proof, since upstream only proves macOS.

**Re-entry conditions (no indefinite dual install):**
- Gates 1–5 pass for a candidate → pin that single version and complete V1 retirement.
- No candidate passes → keep v2.5.0 + local plugins as the single stack and record concrete re-entry conditions; do not run v3/v4 in parallel.

## Risks

- OpenCode V2 native review is unproven on Linux x86_64 (3/4 hosts); macOS-only upstream proof does not transfer to NixOS hosts.
- Plugin API shape drift between OpenCode 2.0.14 → 2.0.18/2.0.19 (#5042/#4795) threatens the repo's vendored `engram-v2.ts` and review transport.
- `#4807` launcher fork-bomb via PATH wrappers (nix named explicitly) intersects the repo's own `opencode2` launcher/standalone work; verify overlap before trusting the launcher.
- SDK version divergence (repo 2.0.14 vs upstream 2.0.4) must be resolved declaratively; upstream's managed-plugins/SDK-manager path is not exercised by this repo.
- Installer/sync defects are likely bypassed by declarative integration, but that bypass must be confirmed per-host rather than assumed.

## Ready for Proposal

**Yes — with a gate.** The proposal must (a) record that the v3-vs-v4 pin is
deferred pending gates 1–5 above, (b) state the provisional v3.7.0 lean and that
it is a scope preference, not a stability finding, (c) treat SDD→ODD as
authorized-if-stable migration effort rather than a disqualifier, and (d) commit
to a single stack with no indefinite coexistence. The proposal must not activate,
bump, or migrate anything until those gates return.
