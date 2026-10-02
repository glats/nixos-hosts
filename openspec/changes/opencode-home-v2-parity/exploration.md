# Exploration: opencode-home-v2-parity

## Summary

`opencode-home` is **not** an OpenCode config/migration concept and does **not**
appear in the official V1→V2 migration guide. It is a **repo-specific Go
command** (`pkgs/nixos-scripts/cmd/opencode-home/main.go`) that is the **macm5
scoped proxy launcher**: it probes the sing-box loopback mixed inbound
(`127.0.0.1:2080`), conditionally exports `HTTPS_PROXY`/`HTTP_PROXY` only while
that inbound is listening, then `exec`s the bare `opencode` binary. Its contract
is "do NOT use plain `opencode` — the wrapper scopes the proxy to the process and
keeps child MCPs clean" (`docs/home-link.md:126`).

The user's suspicion is **partially validated**, but must be framed precisely:

- `opencode-home` **still works today**, because V1 is still the default command
  (`opencode` = V1) and the V1→V2 cutover is **NO-GO** (`docs/opencode-v2-final-cutover.md:8`).
- Its special functionality was **explicitly flagged** in the migration's own
  exploration as needing version-awareness for V2
  (`openspec/changes/migrate-opencode-v1-to-v2/exploration.md:400-404, 418-422`),
  and that work was **never done** — `opencode-home` was **never touched** by any
  migration commit (see timeline below).
- The V2 launcher (`opencode2()` shell function, `shared/shell-aliases.nix:170-190`)
  does **not** replicate the proxy-scoping half of the contract. Only the MCP
  scrub half is ported (`shared/opencode/runtime-config.nix:25-41`).

Net: nothing is broken today; the risk is a **latent parity gap** that
materializes if/when the user runs V2 on macm5 expecting the same
"rides-the-tunnel" behavior, and at the eventual cutover.

## What `opencode-home` actually is

A Go launcher, 49 lines, no dependencies. `pkgs/nixos-scripts/cmd/opencode-home/main.go:1-49`:

1. `nc -z -w 1 127.0.0.1 2080` connect-only probe (`main.go:28-35`).
2. If listening → export `HTTPS_PROXY`/`HTTP_PROXY=http://127.0.0.1:2080`
   (`main.go:30-32`); else print a stderr notice and run clean (`main.go:34`).
3. `exec.LookPath("opencode")` + `syscall.Exec` the bare `opencode` binary
   (`main.go:39-48`).

Special functionality (the "special things that must keep working"):

- **Scoped proxy steering**: only this launcher exports proxy vars; shell
  profiles and the tunnel daemon MUST NOT (`spec.md:64`). It routes OpenCode's
  OpenAI traffic through the macm5→rog TLS tunnel via the loopback proxy door,
  bypassing the corporate security agent's SNI-level interception
  (`docs/home-link.md:29`, `docs/home-link.md:123-129`).
- **MCP-child hygiene**: child MCP processes must remain proxy-clean (the scrub
  is enforced separately in generated config, not by the launcher itself).
- **Graceful degradation**: link down → launcher still starts OpenCode without
  proxy (fail-open on launch).

Governing spec: `openspec/specs/macm5-openai-tls-tunnel/spec.md`, requirement
"Proxy-Environment and MCP Isolation" (`spec.md:60-78`).

## Migration history recovery

### Timeline (committed history)

| Date | Commit | Event |
|------|--------|-------|
| 2026-09-04 | `3a994e0` | `feat(scripts): port workflow scripts to Go (W3)` — bash `bin/opencode-home` → Go |
| 2026-09-05 | `9e91956` | co-locate Go module with derivation (relocate-go-module) |
| 2026-09-06 | `e178e24` | ponytail pass; removed "speculative opencode-home fallback" (Engram #2377) |
| 2026-09-16 | `0e00b36` | `feat(darwin)!: retire mact2` — defaults/comments mact2 → macm5 |
| 2026-09-24 | `08243aa` | `feat(opencode): add isolated v2 runtime` — Go `cmd/opencode2` dropped (dir now empty), replaced by `opencode2()` shell fn |
| 2026-09-22 → 10-01 | `migrate-opencode-v1-to-v2`, `port-gentle-ai-sdd-to-opencode-v2`, `complete-opencode-v1-to-v2-migration` | V2 runtime + adapters + ledger; **NO-GO**, V1 still default |

**Key negative finding**: no commit in the migration series touches
`cmd/opencode-home/`. `git log --follow` on the file ends at `0e00b36`
(2026-09-16), before the migration began (2026-09-22).

### Prior SDD/Engram decisions (retrieved)

- `migrate-opencode-v1-to-v2/exploration.md:287-292, 306-309, 336-337, 400-404, 418-422`
  listed `opencode-home` among the "operational launchers that assume a single
  binary name and V1 data paths" and stated it "must become version-aware" and
  "the macm5 `opencode-home` proxy launcher and the sing-box loopback are
  V1-specific and must be extended to V2". This was carried as a *flag*, never
  implemented.
- `complete-opencode-v1-to-v2-migration/proposal.md` scope lists the V2 runtime,
  adapters, and cutover decision — `opencode-home` is **absent** from scope and
  from all 22 gate IDs in `evidence-ledger.md`.
- `docs/opencode-v2-final-cutover.md` describes moving V2 config/data into
  default XDG roots; it never mentions the proxy launcher or macm5 steering.
- Engram #2377 (2026-09-06): the ponytail pass deleted "speculative
  opencode-home fallback" from the Go module — historical only.

### Current worktree state

`git status -sb` shows dirty files unrelated to `opencode-home` (engram-v2.ts,
engram-v2.test.ts, engram/default.nix, several docs/tasks). `cmd/opencode-home/main.go`
is **clean and unmodified**.

## Behavior parity inventory

| Behavior | V1 (opencode-home) | V2 (`opencode2()` fn) | Status |
|----------|--------------------|-----------------------|--------|
| Probe loopback inbound 2080, conditional proxy export | `main.go:28-35` | absent | **MISSING** |
| `exec` bare binary with scoped env | `main.go:39-48` | `exec .../opencode2` (isolation env only) | **PARTIAL** (exec exists, no proxy scoping) |
| MCP-child proxy scrub (HTTPS/HTTP/ALL_PROXY="", NO_PROXY="*") | generated V1 `mcp.environment` | `runtime-config.nix:32-41` | **VERIFIED** (ported) |
| No shell-profile proxy export | `spec.md:64` | (no V2 launcher export) | **VERIFIED** (neither exports in profiles) |
| Fail-open when link down | `main.go:34` | N/A (no proxy at all) | **UNCERTAIN** (no V2 proxy path to fail open) |
| Version-aware selection (V1 vs V2) | N/A | `opencode2` opt-in wrapper | **VERIFIED** (V2 is separate opt-in) |
| macm5 rides tunnel via proxy door | yes (V1) | **unproven** | **UNCERTAIN** |

**The missing/uncertain items are the substance of the suspicion.** The V2
runtime reproduces the MCP scrub but not the process-level proxy scoping. Whether
V2 on macm5 even *needs* the proxy door (vs. full-mode TUN "MAY traverse solely
by routing", `spec.md:64`) is unanswered — no runtime gate in the ledger covers it.

## Affected Areas

- `pkgs/nixos-scripts/cmd/opencode-home/main.go` — the launcher; `exec.LookPath("opencode")`
  binds it to V1 by name; no version-aware path.
- `shared/shell-aliases.nix:170-190` — `opencode2()` shell fn: where a V2 proxy-scoped
  launcher (or `opencode-home2`) would live; currently has no proxy logic.
- `shared/opencode/runtime-config.nix:25-41` — V2 proxy scrub (already correct; do not regress).
- `openspec/specs/macm5-openai-tls-tunnel/spec.md:60-78` — governing contract; still
  references `bin/opencode-home` (stale pre-Go bash path) and speaks only to the
  V1-shaped launcher.
- `docs/home-link.md:123-129, 155, 163-176, 253` — runbook that commands
  `opencode-home` (V1) with no V2 counterpart instructions.
- `docs/opencode-v2-final-cutover.md` — cutover procedure omits macm5 proxy steering.
- `pkgs/nixos-scripts/default.nix:39` — registration (unchanged; still built).
- `pkgs/nixos-scripts/cmd/opencode2/` — empty directory (deleted Go Docker sandbox;
  historical).

## Approaches

1. **Port the launcher to be version-aware (recommended)**
   Extend `opencode-home` (or add `opencode-home2`) to accept a target version
   (`opencode` V1 vs `opencode2` V2) and apply the same probe/conditional-proxy
   + MCP-scrub contract before `exec`. Reuse the single HM isolation env
   function as the source of truth for the V2 roots, consistent with
   `shared/shell-aliases.nix`.
   - Pros: preserves the exact "special functionality" for both versions; one
     code path; minimal new surface; aligns with the migration's own flag.
   - Cons: must decide whether V2 actually needs the proxy door on macm5
     (runtime question); touches the tunnel contract.
   - Effort: Medium.

2. **Declare opencode-home V1-only and document the V2 path as TUN-routing only**
   Confirm on macm5 that V2 full-mode TUN routing covers OpenAI traffic without
   the proxy door; leave the launcher V1-only and document "V2 on macm5 rides the
   TUN directly, not the proxy door."
   - Pros: zero code; honors the spec's "MAY traverse solely by routing" clause.
   - Cons: abandons the SNI-interception bypass for V2 if TUN routing is
     insufficient; risks silently breaking V2 OpenAI on macm5.
   - Effort: Low (verification + docs only).

3. **Defer entirely until cutover**
   Record as an explicit out-of-scope/deferred item on the cutover checklist;
   do nothing now while V1 remains default.
   - Pros: honest; no premature work; V1 is unchanged.
   - Cons: does not resolve the user's concern; leaves a known latent gap at
     cutover with no decision recorded.
   - Effort: Low (bookkeeping only).

## Recommendation

**Approach 1, preceded by a small macm5 runtime verification step.** Before any
implementation, run a bounded read-only check on macm5 to determine whether V2's
OpenAI traffic is actually intercepted without a proxy (i.e., whether full-mode
TUN routing alone suffices). That single fact decides whether the port is a
behavior-preserving extension (route V2 through the proxy door) or merely a
documentation/selection change. Do not author code until that is established —
the migration ledger's own discipline is "runtime evidence, not authored code as
proof." Record the outcome in the eventual proposal.

## Risks

- **Latent cutover breakage**: if `opencode` is ever flipped to V2 or the V2
  runtime adopts default XDG roots, `exec.LookPath("opencode")` changes meaning
  and the launcher's proxy semantics become un-scoped.
- **Silent V2 OpenAI interception on macm5**: if TUN full-mode routing does not
  cover OpenAI (SNI-level agent interception), V2 OpenAI traffic would be
  intercepted with no warning — the exact failure the launcher exists to prevent.
- **Spec drift**: `spec.md:64` references `bin/opencode-home` (bash), not the Go
  command; acceptance tests could target a path that no longer exists.
- **Over-engineering risk**: building a V2 proxy launcher before proving V2 needs
  it contradicts the repo's YAGNI discipline.

## Ready for Proposal

Yes — **after** the bounded macm5 verification step resolves the one open
question (does V2 on macm5 need the proxy door, or does full-mode TUN routing
suffice?). The orchestrator should tell the user: the suspicion is real but
latent, not a live break — `opencode-home` still works because V1 is still
default and cutover is NO-GO. The missing piece is the **V2 proxy-scoping
launcher parity**, which the migration flagged but never implemented.

## Acceptance conditions (for the later proposal/spec)

- A declared answer, backed by macm5 runtime evidence, to: "does V2 OpenAI
  traffic on macm5 require the `127.0.0.1:2080` proxy door, or does full-mode TUN
  routing cover it?"
- If the proxy door is required: a version-aware launcher (V1 + V2) that probes
  the inbound, exports proxy vars only while listening, and execs the selected
  binary with the correct isolation env; MCP scrub preserved for both.
- If it is not required: the runbook and cutover doc explicitly state the V2
  macm5 routing path, and `opencode-home` remains V1-only without ambiguity.
- `spec.md` updated so its launcher reference matches the actual binary path
  (Go command, not `bin/opencode-home`), or the historical reference is
  explicitly scoped.
- No regression to `runtime-config.nix` proxy scrub; no shell-profile proxy export.
- `nix flake check --no-build` + Go suite (`go -C pkgs/nixos-scripts test ./...`)
  and host evals pass if code changes.
