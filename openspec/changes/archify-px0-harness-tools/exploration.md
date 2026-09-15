## Exploration: archify-px0-harness-tools

### Current State

The shared Home Manager profiles enable both OpenCode and Claude Code on Linux and x86_64-darwin (`linux/home/shared-modules.nix`, `darwin/home/shared-modules.nix`). `shared/ai-assets.nix` defines a common ordered `skillSources` list; the activation unions those sources into `~/.config/opencode/skills` and `~/.claude/skills` (`shared/opencode/runtime-config.nix:223-250`, `shared/claude-code.nix:275-302`). Locally owned skill packages are shipped through `pkgs/local-ai-assets/default.nix` from `shared/assets/skills`; `shared/skills.nix` is a legacy direct deployment exception.

Archify is MIT-licensed, explicitly supports Claude Code and OpenCode, and is a Node >=18 skill package whose renderer compiles typed JSON IR into self-contained HTML/SVG ([README](https://github.com/tt-a1i/archify/blob/d673e8300df60a5c8166abe78787fdc78f6b8000/README.md), [`archify/package.json`](https://github.com/tt-a1i/archify/blob/d673e8300df60a5c8166abe78787fdc78f6b8000/archify/package.json)). Its static output has no server/runtime dependency, but generation needs Node; optional `preview` starts a random loopback server and `--open` launches a browser. The packaged skill also performs an update-manifest GET unless `ARCHIFY_UPDATE_CHECK_DISABLED=1` is set.

px0's canonical repository is `px0-ai/px0`, not a Context7 library (Context7 resolution found only unrelated PX4/Gainsight entries). It is an MIT Go 1.25 single-binary local web application: it binds `127.0.0.1:7777` by default, opens a browser, offers fuzzy navigation, text search, Nix syntax highlighting through Chroma, and git diffs against `HEAD` ([README](https://github.com/px0-ai/px0/blob/4c282c8ee128db58059127b153171ce849fac14b/README.md), [`main.go`](https://github.com/px0-ai/px0/blob/4c282c8ee128db58059127b153171ce849fac14b/main.go)). It is not a terminal application or OpenCode/Claude skill. Nix package searches found neither `archify` nor `px0`; the MCP cannot expose the repository's exact pinned 26.05 channel, so a final derivation still needs a pinned-source build check on both target systems.

### Affected Areas

- `shared/ai-assets.nix`, `pkgs/local-ai-assets/default.nix` — the canonical cross-tool path for a vendored Archify skill source, if adopted.
- `shared/opencode/runtime-config.nix`, `shared/claude-code.nix` — already deploy the same skill union; no bespoke per-agent installer is needed.
- `lib/packages.nix`, `overlays/linux.nix`, `overlays/darwin.nix` — cross-platform package exposure for px0 or an Archify runtime wrapper.
- Linux/Darwin Home Manager package modules — px0 belongs in declarative user packages, not an agent skill or operational script.
- `shared/opencode.nix` and `shared/claude-code-profile.nix` — existing tool permissions make generated HTML and repository facts potentially sensitive; no secrets should be embedded in artifacts.

### Approaches

1. **Separate, opt-in Archify skill and px0 package changes** — vendor a pinned Archify release under the existing asset source and package px0 from a pinned commit with `buildGoModule`; expose px0 only through common Home Manager packages.
   - Pros: follows established deployment paths; Archify is available to both agents; px0 remains a human review tool; versions, hashes, telemetry, and update policy are reviewable; no Bash helper.
   - Cons: two upstream supply chains and two testing matrices; px0 needs a real 26.05 Linux/x86_64-darwin build proof.
   - Effort: Medium.

2. **Adopt Archify only, as an on-demand documentation/artifact generator** — ship its complete skill assets, set `ARCHIFY_UPDATE_CHECK_DISABLED=1`, and require output under an ignored docs/artifacts location only when requested.
   - Pros: strong fit for SDD designs, runbooks, and PR architecture deltas; deterministic validation/delivery; generated HTML is portable and browser-readable; no px0 security exposure.
   - Cons: expands agent context and requires Node/browser only when generating or viewing; diagrams can misstate repository behavior unless agents use verified evidence and users review artifacts.
   - Effort: Low-Medium.

3. **Do not integrate px0 yet; reassess after upstream hardening** — retain existing OpenCode read/grep, RTK-filtered shell output, Git tools, VS Code, and browser facilities.
   - Pros: avoids redundant agent-read tooling and a local web server that can expose the entire readable worktree; avoids background GitHub update checks and optional PostHog telemetry; preserves the current declarative boundary.
   - Cons: forgoes px0's distinct visual, low-memory, fuzzy-navigation and side-by-side-diff workflow, especially useful when reviewing changes on remote hosts.
   - Effort: Low.

### Recommendation

Keep these as separate changes. Propose **Archify only** as a repo-managed, on-demand skill/artifact generator, pinned rather than installed through `npx skills`; deploy through `home.ai-assets.skillSources` so the same immutable files reach OpenCode and Claude Code. Disable its update check declaratively and document that only explicitly requested, reviewed HTML/JSON artifacts may be written; never treat an Archify diagram as proof of runtime behavior or merge safety.

Defer px0 rather than package it now. It offers a distinct human browser-review workflow over native agent reads/RTK and VS Code, and it should handle this Nix/git repository through Chroma plus `HEAD` diffs, but it is a very new `0.1.4` project with no nixpkgs package and no official Homebrew support (open [issue #42](https://github.com/px0-ai/px0/issues/42)). Reconsider only after a pinned Nix derivation is proven on Linux and x86_64-darwin and upstream closes the local-origin security defects.

### Risks

- px0's “strictly read-only” claim applies to repository editing, not to all machine effects: its local UI has authenticated POST endpoints that can launch predeclared LSP installers (`lspsetup.go`), its default startup performs a daily GitHub update check (`update.go`), and telemetry can persist `~/.px0/anonymous_id` if a build injects a PostHog key (`telemetry.go`).
- Open px0 [#75](https://github.com/px0-ai/px0/issues/75) reports workspace HTML/SVG served on the px0 origin and able to read API-accessible repository content; [#77](https://github.com/px0-ai/px0/issues/77) reports missing CSP. Do not run it on untrusted repositories or expose `-host 0.0.0.0` until fixed.
- px0's default index rules skip many generated paths but not secrets universally; the browser inherits the user's filesystem access. Binding a remote host intentionally makes the view reachable beyond loopback and requires authenticated transport outside px0.
- Archify creates shareable HTML and browser exports (PNG/SVG/WebM); generated diagrams, source citations, and screenshots can disclose topology, paths, service names, or secrets if agents are allowed to read them. Its source-evidence mode should use public revision-pinned facts only.
- Context7 has current Archify documentation, but no px0 entry; independent Exa results conflicted with an unrelated/newer px0 workflow product page. The canonical GitHub repository and current source were used for px0 conclusions; no API behavior was inferred from the conflicting page.

### Ready for Proposal

Yes, for a narrow **Archify skill integration** proposal with a pinned release, disabled update network check, asset path, artifact location/ignore policy, and Linux/x86_64-darwin Node validation. No, for px0 integration until its open security issues are resolved and a source-pinned `buildGoModule` passes on the repo's actual 26.05 platforms. The proposal should explicitly keep the work unbundled and add no Bash operational helper.

## Key Learnings:

1. The existing skill-source union already deploys one asset package to both OpenCode and Claude Code.
2. Archify supports both target agents and produces validated self-contained HTML, but generation requires Node.
3. px0 is a loopback browser application, not a terminal viewer or an agent skill.
4. px0 has unresolved local-origin security issues that make immediate declarative adoption inappropriate.
5. Archify and px0 serve independent workflows and should not share one implementation change.
