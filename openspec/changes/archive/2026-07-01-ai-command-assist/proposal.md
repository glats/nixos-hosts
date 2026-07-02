# Proposal: ai-command-assist

> **Revision 2**: Rewritten after honest re-evaluation. shell-gpt from nixpkgs
> already provides shlex.quote()-protected command generation with [E/M/D/A]
> confirmation. We install and configure it — we do NOT build from scratch.

## Intent

Provide an AI-powered CLI tool that converts natural language to shell
commands, previews output, and requires explicit confirmation before execution.
The user types `sgpt --shell "undo the last git commit but keep the changes"`
and gets `git reset --soft HEAD~1` with a confirmation prompt.

## Scope

**IN**:
- Install `pkgs.shell-gpt` via Home Manager module (~20 lines)
- Configure nvidia NIM provider via `home.sessionVariables`
- Per-host enable/disable and model selection

**OUT**:
- Custom Python script (shell-gpt IS the tool)
- Custom Nix package derivation
- Fork of shell-gpt
- Danger pattern detection (future tier-1.5 via fork patch if needed)

## Capabilities

1. **Natural Language → Command**: `sgpt --shell` with shell-role system prompt
   generates a single shell command
2. **Confirmation Gate**: [E]xecute / [M]odify / [D]escribe / [A]bort prompt
   before any shell action (built into shell-gpt)
3. **Injection Defense**: shell-gpt's `run_command()` uses `shlex.quote()` —
   blocks `$()`, backticks, `;`, `&&`, and all shell metacharacters
4. **Multi-mode**: one-shot (`--shell`), REPL (`--repl temp --shell`), chat
   sessions (`--chat`) — all included for free
5. **Per-Host Config**: Declarative Nix options for enable, model, baseUrl

## Approach

**Zero custom code**: `pkgs.shell-gpt` is already in nixpkgs. A ~20-line HM
module sets env vars that shell-gpt reads natively. No fork, no Python script,
no package derivation.

**Provider flow**: shell-gpt's internal `openai.OpenAI()` reads `API_BASE_URL`
and `OPENAI_API_KEY` from the environment. We set these via
`home.sessionVariables`, pointing to nvidia NIM. `OPENAI_API_KEY` maps to
`$NVIDIA_API_KEY` (already exported by sops-nix via `shared/opencode.nix`).

**Module options**:
```nix
home.shell-gpt = {
  enable = true;
  model = "nvidia/nemotron-3-ultra-550b-a55b";
  baseUrl = "https://integrate.api.nvidia.com/v1";
  provider = "nvidia";
};
```

**User experience**:
```bash
$ sgpt --shell "list all json files modified today"
> find . -name "*.json" -mtime -1
[E]xecute, [M]odify, [D]escribe, [A]bort:
```

## Affected Areas

| Change | Path | Lines |
|--------|------|-------|
| NEW | `home-linux/shell-gpt.nix` | ~20 |
| MODIFY | `hosts/rog/home/modules.nix` | +1 import |
| MODIFY | `hosts/thinkcentre/home/modules.nix` | +1 import |
| MODIFY | `hosts/t14/home/omarchy.nix` | +1 import (optional) |

NOT in `shared-modules.nix` — follows host-conditional pattern (like conky-rog).

## Risks

| Risk | Mitigation |
|------|------------|
| Destructive command execution via LLM output | [E/M/D/A] confirmation prompt; LLM output is previewed before execution |
| NVIDIA NIM outage | Tool fails gracefully — sgpt shows HTTP error, no crash |
| shell-gpt version drift in nixpkgs | Flake lock pins version; updates are opt-in |
| Model hallucination | User previews command and must confirm; [M]odify and [A]bort available |

## Rollback Plan

1. `home.shell-gpt.enable = false` — removes env vars and package instantly
2. `nixos-build dry` before switch to verify
3. Remove module import from host files
4. No custom code to delete; no new secrets to clean up

## Dependencies

- `pkgs.shell-gpt` (already in nixpkgs, v1.5.1)
- `NVIDIA_API_KEY` env var (already exported by `shared/opencode.nix`)
- nvidia NIM API (external — no new flake inputs)

## Success Criteria

1. `nix flake check --no-build` passes with module imported
2. `nixos-build dry` succeeds on rog with `home.shell-gpt.enable = true`
3. `sgpt --shell "list files sorted by size"` works with nvidia NIM
4. Confirmation prompt appears before execution
5. `home.shell-gpt.enable = false` cleanly disables
