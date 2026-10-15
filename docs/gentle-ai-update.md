# Gentle AI v4 updates on the V2-only fleet

Update the binary, rendered prompts, native relay, managed graph and ownership
inventory as one candidate. Home Manager is the deployment authority; do not
run upstream install/sync/update over Nix-managed assets. A build is not approval
to activate, call models, stage, commit, push or publish.

## Current boundary

| Component | Source/contract |
|---|---|
| Gentle binary and assets | v4.0.0, `ff77164d4f56f1665b22fb6fac51c2ccbb769400` |
| Go | At least 1.25.10; pinned builder currently 1.26.6 |
| vendorHash | `sha256-YL4Slz/UuY+HEcJTW+pMphcdB6xtpam+E4uTDWifEcY=` |
| OpenCode CLI and SDK | 2.0.14; no silent upgrade/downgrade |
| Native relay declaration | `gentle-ai.opencode-relay/v2-staged` |
| Go-owned wire | `gentle-ai.provider-transport/v1` |

`pkgs/gentle-ai-assets/render.nix` runs a build-only Go test inside the vendored
tagged `/v4` module. Its actual upstream renderers produce OpenCode and Claude
prompts plus the ODD/review graph; no exporter CLI is installed. Rendering uses
the real native `.opencode2-unwrapped`, never a fabricated version executable.

The HM-scoped compiled `gentle-ai` wrapper restores the full V2 environment for
its children and privately prefixes truthful bare `opencode` discovery plus Git.
Host-config shell scrubbing cannot remove those child settings. Public commands
stay `opencode2` and Darwin-only `opencode2-home`; no global bare alias is added.
The managed relay and registry use the absolute wrapper path. Go alone owns
review role binding, materialization, budgets, admission and receipts.

## Candidate checks before rollout

1. Verify the release tag resolves to the approved immutable commit. Update only
   `gentle-ai-src` in `flake.nix`/`flake.lock`, package version/hash/toolchain and
   coupled asset/graph changes. Never follow a moving branch or sync marker.
2. Resolve the vendoring hash with a temporary fake hash build if dependencies
   changed, then replace it with the observed real hash. Build binary and assets.
3. Run focused tests and inspect every failed/skipped check:

   ```sh
   bun test pkgs/gentle-ai-assets/opencode-review-transport.test.ts
   python3 shared/opencode/v2-agents.test.py --odd-candidate
   python3 shared/opencode/home-launcher.test.py --odd-candidate
   python3 shared/opencode/asset-ownership.test.py
   go -C pkgs/nixos-scripts test ./...
   nix build --no-link .#gentle-ai .#gentle-ai-assets
   nix flake check --no-build
   ```

   While new files remain untracked, use the explicit source installable
   `path:/home/glats/.nixos#gentle-ai-assets` (substitute the local checkout path)
   and `nix flake check --no-build path:/home/glats/.nixos`; never stage merely to
   make a Git-filtered flake see them. Python fixtures use explicit path sources.
4. Evaluate three Linux system/integrated HM targets, all four standalone HM
   targets, and Darwin system/integrated HM separately. Native Darwin builds and
   cross-platform IFD cannot be certified from Linux; unavailable is UNVERIFIED.
5. Compare complete provider profiles outside approved ODD mappings and the
   explicitly approved retirement/alias exceptions below. Explore,
   worker and verify inherit the former explore/apply/verify fits; user overrides
   remain last-wins. Keep provider policy, NVIDIA declaration, MCP/Engram/RTK,
   launcher arguments, standalone/server/proxy behavior and namespace roots.

The tagged installer SDK equality check does not prove managed 2.0.14 runtime
incompatibility. A demonstrated incompatibility blocks adoption until an
explicit runtime-upgrade decision; unit tests cannot advertise organic capability.

### Approved routing retirement (2026-10-09)

Operator decision #3979 retires exactly `opencode-free`,
`anthropic-opencode-free`, and `anthropic-opencode-go`; it does not assign a new
model or waive model-fit evidence gates. Their MiMo route is deprecated in the
public catalog and filtered by native 2.0.14. The proposed free replacement did
not pass the required evidence gates, so there is no automatic or paid fallback.
Explicit selection of a retired name must fail configuration; external callers
must obtain an operator-approved alternative rather than silently redirect.

The 32 remaining profile objects and ordering are unchanged after the existing
ODD mappings. Both integrated and standalone selections remain `openai-medium`
on rog and `openai-anthropic-go` on thinkcentre, t14 and macm5, with unchanged
overrides. NVIDIA gains only the native model alias `nemotron-3-ultra-550b-a55b`
with `modelID = nvidia/nemotron-3-ultra-550b-a55b`, preserving the same backend
model, endpoint and authentication settings; no NVIDIA role selectors change.

The catalog proof covers 23 built-in and three custom selectors with zero
usable-missing entries. It is not a live tool-call, entitlement or uptime proof.
Retirement changes the reviewed source fingerprint and generated configuration:
rerun shared evaluation and native platform configuration/build gates. Keep old
build evidence as historical evidence, not proof of the repaired candidate.

## Ownership and unfinished work

`ai-assets-reconcile` is a thin Go operational tool in the existing
`nixos-scripts` package. V2, Claude and OpenFang consume immutable union trees.
Their per-root `.gentle-ai-owned.json` records installed digests, source revision
and original rollback bytes. Schema 2 pending entries separately record the
immediate prior state (including explicit absence) and desired digest. Completed
entries clear pending retry authority; historical rollback bytes never authorize
replacement. Schema 1 manifests are conservatively read for installed digests,
not historical before-image retry authority. Every path is preflighted before asset writes; symlink
escapes, foreign collisions and modified retirements refuse without deleting
user data. Replacements are file-atomic and journaled first for idempotent retry.
No directory is recursively deleted or user tree swept for generic orphans.
Persistent per-root `.gentle-ai-owned.lock` uses native advisory `flock` on Linux
and Darwin to serialize reconciler processes through journal and completion.
Never unlink this lock while another reconciler may be running. Replacements
recheck preflight bytes immediately before rename; absent targets use a
same-directory no-clobber hard-link install. Modified paths refuse rather than
overwrite. Advisory locks do not stop external editors: an existing file or
ancestor may still change after the final check. This narrows that race window,
not a full TOCTOU guarantee, cross-root transaction or power-loss durability
guarantee. Consumer activations still preflight independently; an already
completed consumer/file is not rolled back when a later conflict refuses.

Bootstrap evidence comes from the exact prior repository generation
`4750736cd68f517a871ac7448639c94546472390` and its complete lock/pinned 2.5 asset
sources. V2 bootstrap reproduces the actual prior command/skill remaps and phase
marker bytes; Claude uses its distinct prior assets. This historical inventory
is not a second active production stack. Modified or unproven old assets require
explicit reconciliation before activation; do not force around the refusal.

The current migration remains tracked in
`openspec/changes/gentle-ai-v4-odd-v2-only/`; history is not converted. Before
retiring another unfinished workflow, the user must select the work and approve
a handoff linking its original artifacts, stable task IDs, actual code/evidence
and remaining gates. Never bulk-convert OpenSpec or create ODD feature documents
for unselected work. Future substantial ODD work uses `odd/tasks/<feature>.md`
and a full project Engram `odd/<feature>/tasks` mirror, with readback and explicit
pending-mirror/conflict handling. Prompt text alone does not prove that behavior.

## Authorized rollout and rollback

Only after independent candidate review and separate model/network consent,
prove native delegation and real lens/refuter/validator receipts with negative
cases on rog. Separately authorize rog-first activation, then each other host.
Keep native Darwin and each host's runtime/MCP/Engram checks distinct; rog or
loopback success is not fleet certification. Do not restart the current harness
or active sessions during this implementation.

Rollback restores the coupled prior source/lock/package/assets/graph changes and
approved system/HM generations, never V1. Preserve credentials, sessions,
receipts, archives, OpenSpec and ODD documents, unrelated work and Git index.
Before generation restoration, use the retained prior/current immutable asset
trees with the same reconciler in a reviewed recovery procedure, or restore
only digest-matching managed before-images. Refuse modified files; never copy
an entire directory over a user's tree or reinterpret newer receipt authority.
Keep migration evidence and journals until rollback is no longer needed.
