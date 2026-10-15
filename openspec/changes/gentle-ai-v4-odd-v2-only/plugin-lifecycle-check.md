# Managed plugin lifecycle: offline reconciler gates pass

S3 is PASS for the shipping reconciler's desired-inventory lifecycle: only digest-proven owned plugins retire, foreign collisions refuse before asset writes, and archives/history survive. S5 retirement and rollback are PASS in synthetic consumer roots only. This is not Home Manager activation, a live canary, plugin execution, or fleet rollout approval. Evidence was collected on 2026-10-09 under continuous NONLIVE authorization #3961; live boundaries remain unchanged.

## Acceptance coverage

The current delta specification, `specs/gentle-ai-declarative-runtime/spec.md`, defines disabled/legacy reconciliation as retiring **only proven-owned executable files**, with archives preserved. Here “disabled” means absent from the supplied desired inventory. The current `shared/opencode/runtime-config.nix:78-86` supplies a fixed managed plugin map; no public `home.opencode.plugins.*.enable` interface exists in current shared Nix. The superseded specification's public-toggle scenario is therefore N/A, not an implemented or tested toggle.

| Gate | Result | Observed evidence and boundary |
|---|---|---|
| S3: enabled file deployment | PASS, filesystem scope | Exact desired `skill-registry.ts` bytes install at one active plugin path, mode 0644; repeat reconciliation is byte/mode-identical. No runtime/server was started. |
| S3: individual plugin retirement | PASS | A writable synthetic desired tree contains the exact current V4 asset bytes except `plugins/skill-registry.ts`. Reconciliation removes that owned plugin and its completed ownership entry. |
| S3: retained plugins and user data | PASS | Host-config, RTK, Engram and the other retained plugin bytes/modes remain unchanged; synthetic archive/plugin copy, history, credentials, receipts, Engram mirror and unfinished OpenSpec/ODD files survive. |
| S3: repeated disable and reenable | PASS | Second disable changes no file byte/mode. Reenable restores exact current plugin bytes into owned absence; repeat enable is idempotent. |
| S3: modified disabled owned plugin | PASS | Refuses `modified managed retirement requires explicit reconciliation`; manifest and every target file byte/mode remain unchanged, including a separate desired asset update that would otherwise be written. |
| S3: foreign reenable collision | PASS | After retirement, synthetic foreign bytes at the same filename refuse `unowned or modified asset collision`; no filename-only ownership claim or overwrite. |
| S3: exact known prior plugin | PASS | Exact prior V2.5 `plugins/sdd-task-result.ts` retires; input SHA256 `68059a47df24fa337140a4dbcdf928b184f26e6de5d36587f294e684dd131288`. |
| S3: foreign known-legacy filename | PASS | Different bytes at that legacy filename refuse `modified legacy retirement requires explicit reconciliation`; all existing assets survive and no ownership manifest is created. The reserved mode-0600 lock may be created before preflight. |
| S3: unknown legacy / inactive V1 | PASS, preservation scope | Uninventoried synthetic active `background-agents.ts` remains foreign and is not journaled. A separate synthetic `.opencode/plugins/background-agents.ts` sibling remains untouched. No claim that unknown V1 bytes are deleted, and no real V1 directory was accessed. |
| S5: owned SDD retirement across consumers | PASS, synthetic only | Reused actual-tree harness passes V2/Claude/OpenFang legacy bootstrap, SDD skill retirement, owned plugin retirement, foreign preservation, modified refusal, exact prior-tree rollback and retry. |
| S5: second-generation recovery | PASS, synthetic only | Existing harness passes planned immediate-predecessor retry, clears pending authority, preserves original before-image, and refuses user/historical byte substitutions. |
| Public per-plugin HM toggle | N/A | Not a current interface; no option was invented or added. |
| S2 full HM enabled-plugin acceptance | UNVERIFIED | No real activation, host-by-host deployment or organic/runtime proof. |
| S5 installed-byte canary | UNVERIFIED | No live home, installed generation or real canary was mutated. |

The acceptance boundary is intentionally narrower than fleet approval. S3's reconciler evidence is complete; S5's remaining live activation gate is unchanged. Unknown historical assets remain user data rather than being guessed into the prior inventory.

## Reproduction and proof artifacts

All writable fixtures are under `/home/glats/.local/opencode-v2/tmp/opencode`. The successful run exited 0. No Nix build, activation, service, MCP/provider call, credential read, or source edit was needed: all seven required cached outputs (six asset trees plus the shipping CLI) already existed.

```sh
nix eval --impure --json --expr '
let f = builtins.getFlake "path:/home/glats/.nixos";
    h = f.homeConfigurations.rog.config;
in {
  v2 = builtins.getContext h.home.activation.setupOpencodePluginRuntime-v2.data;
  claude = builtins.getContext h.home.activation.deployClaudeCodeAssets.data;
  openfang = builtins.getContext h.home.activation.syncOpencodeSkillsToOpenfang-v2.data;
  source = f.inputs.gentle-ai-src.outPath;
}' > /home/glats/.local/opencode-v2/tmp/opencode/plugin-lifecycle-contexts.json

python3 -u /home/glats/.local/opencode-v2/tmp/opencode/plugin-lifecycle-proof.py \
  > /home/glats/.local/opencode-v2/tmp/opencode/plugin-lifecycle-proof.log 2>&1
```

The proof resolves output paths using `nix-store --query --outputs`, verifies their existence, and invokes the cached CLI directly. Its individual-plugin subset fixture excludes only `skill-registry.ts`; every other desired file has the exact original SHA256. It executes the existing `shared/opencode/asset-ownership.test.py` assertion bodies in memory, replacing only context evaluation with the already captured JSON and its build call with cached-output existence checks. The repository harness itself is unchanged. TemporaryDirectory is directed to the approved fixture base, not system `/tmp`.

Successful durable fixture root: `/home/glats/.local/opencode-v2/tmp/opencode/plugin-lifecycle-2p4wtr19`.

| Artifact | SHA256 |
|---|---|
| Nix CLI `/nix/store/bws48mvkrsp07d4a7cm0bbxjvsiag0mn-nixos-scripts-1.0.0/bin/ai-assets-reconcile` | `51f260fec85c701477d5efc77d4132f44b9d42cdf06c309aa99a1f9084bfc012` |
| Fixture script `plugin-lifecycle-proof.py` | `d9d4a8b519e5111e60ac68c55b94f660eff1628c080dcf036b82c4f9ea89675e` |
| Successful log `plugin-lifecycle-proof.log` | `013ece7f4032f89a879834002511e9edd7ca2e289728fe04ac062a1222d1917d` |
| Root `descriptor.json` | `904843b18966c419b71f555e45b44ce35d961cb8e178776276fcf4b03f65dad4` |
| Root `six-asset-inventories.json` | `72bf6d253899ef8751b2cffeceaf3379035e29b331e5c78b7bd8d475ba2338d5` |
| Root `cli-transcript.jsonl` | `03ef62dff1c93d98915e7dc8625ceadf48c029a076d6e1af36b98609846bd098` |

The descriptor contains exact public activation contexts, output paths and CLI provenance. The transcript records each added lifecycle command, exit status and diagnostic. Existing harness assertions report their pass results in the successful log. All credentials/history bytes in fixtures are explicit synthetic strings.

## Six actual asset trees remain unchanged

Every actual source-tree file SHA256 and mode was compared before/after the successful run. These are inventory fingerprints, not NAR hashes: SHA256 of compact, sorted-key JSON mapping relative paths to `{sha256, mode}`.

| Consumer / version | Cached store output | Files | Inventory fingerprint |
|---|---|---:|---|
| V2 prior | `/nix/store/x1h31dg3b0p4agp946lawd94790b6wih-gentle-ai-2.5-owned-v2` | 4544 | `bc7599941ecb4a858968b11794634a67ee519fec88190517f069a84a373ccedf` |
| V2 desired | `/nix/store/132r95j516jryw0pzv9r4aqxg17pvgcz-opencode-v2-owned-assets` | 4514 | `3229d26abcfa672ca63e64dcd30d41a55c216bf34f3bd3c665f0d6df162fb663` |
| Claude prior | `/nix/store/j63s7ann346w137a5p96cmj8pry7caaa-gentle-ai-2.5-owned-claude` | 4547 | `9650a77a8457d24e697d00a60212aae55d14cbe75bb51ff3d4445556bd8a9ee4` |
| Claude desired | `/nix/store/5v1cinj61xmfy3ns8ix8s2l1s120l3zy-claude-owned-assets` | 4507 | `0eeffa5f1859cbe357aa0746652551fdf1b585b4887d96c6d2fb74998697b555` |
| OpenFang prior | `/nix/store/1cydh5zwg4mxx9iir8j4m9fln70nfz89-gentle-ai-2.5-owned-openfang` | 4537 | `d7382c7a0fe671b4e1aeae722538c1351d4833ecaf259bd1e4847e0a89c9c6f4` |
| OpenFang desired | `/nix/store/awmmmw35scjk7641gvz272vq085aq9xr-openfang-owned-skills` | 4494 | `390394f6cce404aee1d287190e2a3dfccb6d5ba555c75d8a82101da33c6fd7ce` |

## Reused safety evidence and limitations

Engram #3923 already verifies the same cached CLI's symlink/ancestor and locking guards, concurrent edit refusal and second-generation journal recovery. Those specialized cases were not duplicated here; the existing actual-tree recovery assertions were rerun. The documented existing-file check-to-rename race window is not claimed eliminated.

Two fixture-only expectation mistakes were corrected before the successful run: writable copies have different modes from immutable store sources, so subset fidelity compares exact bytes; and first-use refusal can create the reserved lock, so no-writes assertions distinguish synchronization metadata from assets/manifest. One initial 120-second wrapper expired during repeated large inventory comparisons; the final bounded 600-second run completed successfully. These were not product failures and required no source fixes.

`shared/rules/authorization.md` remains authoritative: a successful task/check/receipt does not authorize Git publication, activation, service changes or credential access. Historical unfinished OpenSpec/ODD work was retained as synthetic data; no bulk conversion, task completion or LLM execution proof is implied. Only this report and Engram were changed in the repository/documentation scope; task registers and common progress reports remain for the parent session.
