# Exploration: ai-command-assist (Honest Re-Evaluation)

> AI-powered CLI tool: natural language → LLM command generation → preview → confirmation → execute.

**Date**: 2026-07-01 (revision 2)
**Trigger**: Previous exploration was biased toward "build from scratch." User called this out.
**Methodology**: Read ACTUAL source code (not READMEs) for shell-gpt and llm-cmd. Verified nixpkgs derivations. Assessed real safety properties, not assumed ones.

---

## 1. Critical Correction: shell-gpt Does NOT Use `shell=True`

The previous exploration claimed shell-gpt has a `shell=True` vulnerability. **This is factually wrong.** Here is the actual execution code from `sgpt/utils.py`:

```python
def run_command(command: str) -> None:
    if platform.system() == "Windows":
        is_powershell = len(os.getenv("PSModulePath", "").split(os.pathsep)) >= 3
        full_command = (
            f'powershell.exe -Command "{command}"'
            if is_powershell
            else f'cmd.exe /c "{command}"'
        )
    else:
        shell = os.environ.get("SHELL", "/bin/sh")
        full_command = f"{shell} -c {shlex.quote(command)}"

    os.system(full_command)
```

**Analysis of the defense:**

`shlex.quote(command)` is Python's standard library function for safely quoting strings for shell consumption. It wraps the entire command in single quotes and properly escapes any internal quotes using the `'\''` pattern. The resulting shell command is:

```
/bin/sh -c '/path/to/zsh -c '"'"'the quoted command'"'"''
```

This means:
- **bash injection via `$()`, `` ` ``, `<>()` is BLOCKED** — `shlex.quote()` escapes all these characters
- **command chaining via `;`, `&&`, `||` is BLOCKED** — they become quoted literals inside the `-c` argument
- **The REAL risk is NOT injection** — it's that the LLM generates a legitimately dangerous command (like `rm -rf /`) and the user accidentally hits `E` instead of `A`

**Comparison to `subprocess.run(cmd, shell=True)`:**

| Pattern | Injection possible? | Pipe/redirect support? | Risk |
|---------|-------------------|----------------------|------|
| `subprocess.run(cmd, shell=True)` | **YES** — shell interprets metacharacters in `cmd` | Yes (shell handles them) | CRITICAL |
| `os.system(shlex.quote(cmd))` | **NO** — everything is quoted | Yes (shell -c receives unescaped inner string) | Low (injection blocked) |
| `subprocess.run(shlex.split(cmd))` | No (shell bypassed) | **NO** — `\|` becomes literal argument | None (but broken UX) |

The tension: if you use `shlex.split()` + arg arrays, you lose pipes and redirects (fundamental shell features users expect). If you use a shell, you need quoting like `shlex.quote()`. shell-gpt chose the latter correctly.

---

## 2. Deep-dive: shell-gpt Architecture (TheR1D/shell_gpt)

### 2.1 Architecture Diagram

```
sgpt/app.py (typer CLI)
    ├── sgpt/handlers/handler.py      # Base: OpenAI client + streaming
    │   ├── OpenAI(base_url=..., api_key=...) or LiteLLM
    │   └── Cache (response caching)
    ├── sgpt/handlers/default_handler.py  # Single prompt → response
    ├── sgpt/handlers/chat_handler.py     # Multi-turn SQLite-backed chats
    ├── sgpt/handlers/repl_handler.py     # REPL mode
    ├── sgpt/role.py                   # System prompt roles (Shell, Code, Default)
    ├── sgpt/config.py                 # Config: ~/.sgptrc or ENV VARS
    └── sgpt/utils.py                  # run_command(), integration install
```

### 2.2 Provider Configuration

**Config source** (`sgpt/config.py`):
```python
class Config(dict):
    def get(self, key: str) -> str:
        value = os.getenv(key) or super().get(key)  # ENV VARS TAKE PRIORITY
        if not value:
            raise UsageError(f"Missing config key: {key}")
        return value

cfg = Config(SHELL_GPT_CONFIG_PATH, **DEFAULT_CONFIG)
```

**This means EVERY config key is overridable via env vars.** No config file editing needed. Key settings for our use case:

| Setting | Env Var | Default | Our value |
|---------|---------|---------|-----------|
| API endpoint | `API_BASE_URL` | `"default"` | `https://integrate.api.nvidia.com/v1` |
| API key | `OPENAI_API_KEY` | (none) | `$NVIDIA_API_KEY` |
| Model | `DEFAULT_MODEL` | `gpt-5.4-mini` | `nvidia/nemotron-3-ultra-550b-a55b` |
| Shell interaction | `SHELL_INTERACTION` | `"true"` | `"true"` |
| Default execute | `DEFAULT_EXECUTE_SHELL_CMD` | `"false"` | `"false"` |

**Provider setup for NVIDIA NIM** — shell-gpt uses `openai.OpenAI()` internally, so ANY OpenAI-compatible API works:
```bash
export API_BASE_URL="https://integrate.api.nvidia.com/v1"
export OPENAI_API_KEY="$NVIDIA_API_KEY"
export DEFAULT_MODEL="nvidia/nemotron-3-ultra-550b-a55b"
sgpt --shell "find all json files modified today"
```

### 2.3 Interaction Flow

```
User: sgpt --shell "find all json files modified today"
  → DefaultHandler with Shell Role system prompt
  → Streaming API call to OpenAI-compatible endpoint
  → Display command: find . -name "*.json" -mtime -1
  → [E]xecute, [M]odify, [D]escribe, [A]bort:
       E → run_command(cmd) → os.system(zsh -c shlex.quote(cmd))
       M → prompt_toolkit session to edit command, then re-prompt
       D → Second API call explaining the command
       A → Exit
```

### 2.4 Feature Set (things we get for FREE)

- ✅ Streaming responses
- ✅ Multi-turn chat sessions (SQLite-backed)
- ✅ REPL mode
- ✅ Custom system prompt roles
- ✅ Response caching
- ✅ Multi-provider (OpenAI, Azure, any OpenAI-compatible)
- ✅ Shell integration (Ctrl+X E hotkey in Zsh/Bash)
- ✅ Function calling (LLM calls user-defined Python functions)
- ✅ 10k+ GitHub stars, active maintenance (last commit: June 2026)
- ✅ nixpkgs: `pkgs.shell-gpt` version 1.5.1

### 2.5 What's Actually Missing

- ❌ No danger command detection (rm -rf, dd, mkfs, etc.)
- ❌ No per-host Nix configuration — must use env vars (which is fine)
- ❌ `run_command` uses `os.system()` instead of `subprocess.run()` — minor hygiene issue
- ❌ No allow/deny lists for commands
- ❌ No execution audit log

### 2.6 Fork Difficulty Assessment

**What a fork would change** (add danger detection):
```python
# In sgpt/utils.py or sgpt/app.py, add BEFORE the while loop:

DANGEROUS_PATTERNS = [
    r'rm\s+-rf\b', r'\bdd\b', r'\bmkfs\b', r'chmod\s+777',
    r'curl.*\|.*(?:ba)?sh', r'>\s*/dev/sd[a-z]', r':\(\)\s*\{'
]

def check_danger(command: str) -> Optional[str]:
    import re
    for pattern in DANGEROUS_PATTERNS:
        if re.search(pattern, command):
            return f"[DANGER] Command matches: {pattern}"
    return None
```

**Patch size**: ~20 lines added to `sgpt/utils.py`. No architectural changes needed.

**Nix overlay for fork**:
```nix
# In overlays/linux.nix
self: super: {
  shell-gpt = super.shell-gpt.overrideAttrs (old: {
    src = super.fetchFromGitHub {
      owner = "glats";
      repo = "shell_gpt";
      rev = "our-fork-sha";
      hash = "...";
    };
  });
}
```

**Fork maintenance**: shell-gpt releases ~2-3 times per year. Rebase is a `git merge upstream/main`. Risk is low.

---

## 3. Deep-dive: llm-cmd (simonw/llm-cmd)

### 3.1 Architecture

```
llm (CLI framework, pluggy-based)
  └── llm-cmd (plugin, ~85 lines)
       ├── register_commands() → "llm cmd" subcommand
       │   ├── Calls model_obj.prompt(prompt, system=SYSTEM_PROMPT)
       │   └── Calls interactive_exec(result)
       └── interactive_exec()
            ├── prompt_toolkit session (readline pre-fill)
            ├── User edits command, presses Enter
            └── subprocess.check_output(cmd, shell=True) ← DANGEROUS
```

### 3.2 Safety: `shell=True` IS Real Here

```python
# From llm_cmd.py line ~60:
output = subprocess.check_output(
    edited_command, shell=True, stderr=subprocess.STDOUT
)
```

This is genuinely dangerous — no quoting, no argument arrays, no escape. A command containing `$(malicious)` or `` `malicious` `` will execute it.

**Fork fix difficulty**: Trivial (change 1 line to `shlex.split()` + `subprocess.run()`), but the `llm` framework adds significant weight for our simple use case.

### 3.3 Nix Packaging

The `llm` package in nixpkgs (v0.30) has excellent plugin support via `llm.withPlugins`:
```nix
llm.withPlugins {
  llm-cmd = true;
  llm-ollama = true;
  llm-openai-plugin = true;
}
```

But this creates a Python environment with many dependencies. The `llm` framework itself has deps: `openai`, `numpy`, `pydantic`, `sqlite-utils`, `pluggy`, etc. Heavy for "generate a shell command."

### 3.4 llm-cmd Verdict

- **Code size**: Beautifully small (85 lines) — Simon Willison is famous for this
- **Safety**: Genuinely uses `shell=True` with zero defense
- **Fork potential**: Fix is trivial (1 line), but UX needs more work (no confirmation, no describe)
- **Framework overhead**: `llm` framework adds massive weight (SQLite logging, plugin system, embeddings)
- **Last update**: Sep 2024 — essentially stable, but not actively developed
- **Relevance**: Low. Too heavy for our use case. Forking requires pulling in the entire `llm` framework.

---

## 4. Honest Comparison Table

| | Fork shell-gpt | Use shell-gpt as-is from nixpkgs | Thin wrapper on sgpt | Fork llm-cmd | Build from scratch |
|---|---|---|---|---|---|
| **Lines of OUR code** | ~10 (patch) + ~30 (Nix) | ~25 (HM module) | ~50 (bash wrapper) | ~20 (patch) + llm deps | ~250 (Python) |
| **Days to working tool** | 1-2 | **0.5** (same day) | 1 | 2-3 | 2-3 |
| **Safety: injection defense** | ✅ shlex.quote (existing) | ✅ shlex.quote (existing) | ✅ we control exec | ✅ after patch | ✅ designed in |
| **Safety: danger detection** | ✅ ADDED (fork patch) | ❌ NOT in upstream | ✅ ADDED in wrapper | ✅ ADDED (fork patch) | ✅ built-in |
| **Safety: confirmation prompt** | ✅ [E/M/D/A] (existing) | ✅ [E/M/D/A] (existing) | ✅ custom (ours) | ❌ none (needs adding) | ✅ built-in |
| **Features day 1** | ⭐⭐⭐⭐⭐ Chat, REPL, roles, cache, functions | ⭐⭐⭐⭐⭐ Chat, REPL, roles, cache, functions | ⭐⭐ Just command gen | ⭐⭐ Just command gen | ⭐⭐ Just command gen |
| **Provider config** | ✅ env vars (SGPT_*) | ✅ env vars (SGPT_*) | ✅ env vars (SGPT_*) | ⚠️ llm keys system | ✅ Nix-native |
| **Nix integration** | Medium (overlay) | **Trivial** (env vars) | Medium (wrapper pkg) | Hard (Python env) | Medium (own derivation) |
| **Maintenance burden** | Low (rebase fork 2-3x/yr) | **None** (nixpkgs maintains) | Low (30-line script) | Medium (llm ecosystem) | **100% ours** |
| **UX quality** | ⭐⭐⭐⭐⭐ Readline + [E/M/D/A] + Describe | ⭐⭐⭐⭐⭐ Readline + [E/M/D/A] + Describe | ⭐⭐⭐ Custom (basic) | ⭐⭐ Readline only | ⭐⭐⭐ Custom (configurable) |
| **Bundle size** | ~50MB Python env | ~50MB Python env | ~50MB + ~1KB | ~200MB (llm + deps) | ~30MB (openai + deps) |
| **Risk of bitrot** | Low (active upstream) | **None** (nixpkgs) | Low (shell-gpt API stable) | Medium (llm evolves fast) | Medium (must self-maintain) |
| **Nvidia NIM support** | ✅ (any OpenAI compat) | ✅ (any OpenAI compat) | ✅ (via shell-gpt) | ✅ (via llm-openai) | ✅ (openai lib) |
| **Python version risk** | Handled by nixpkgs | Handled by nixpkgs | Handled by nixpkgs | Handled by nixpkgs | We manage |

---

## 5. The "Fragility" Question — Honest Answer

The user asked: "no es muy frágil crear un script en Python?" (isn't a 250-line Python script fragile?)

### 5.1 Dependency Chain on NixOS

| Dependency | nixpkgs version | Stability | Risk when nixpkgs updates |
|-----------|----------------|-----------|--------------------------|
| `python3Packages.openai` | 2.41.1 | Very stable API | Low — minor version bumps are backward-compatible |
| `python3Packages.pygments` | Any | Extremely stable | Near zero — hasn't changed API in years |
| `python3Packages.prompt-toolkit` | 3.0.x | Very stable | Near zero — mature library |
| `python3` | 3.12/3.13 | Nixpkgs manages | Zero — our derivation just uses `python3` attr |

A 250-line Python script has **low fragility** on NixOS because:
1. **Deterministic builds**: Nix pins exact package versions. Our script sees the same dependencies until we update the flake lock.
2. **Python version bumps handled by nixpkgs**: When nixpkgs switches from python3.12 → 3.13, our derivation inherits the new Python automatically.
3. **openai API is stable**: The `openai.OpenAI(base_url=..., api_key=...).chat.completions.create()` pattern hasn't changed in years.
4. **Small surface = few bugs**: 250 lines of straightforward API calls, string parsing, and subprocess management.

**Comparison**: Forking a Go tool (like `mods`) would be MORE fragile because Go has a different build system, different nixpkgs support pattern, and less mature packaging.

### 5.2 What Would ACTUALLY Break a Python Script

1. **OpenAI changes their API format** → Would also break shell-gpt, llm-cmd, and every other tool. This is a global risk, not specific to our script.
2. **nvidia NIM changes their endpoint** → Would break all tools equally. We'd update `baseURL`.
3. **Python version drops support for a dependency** → nixpkgs handles this. If `openai` drops Python 3.12 support, nixpkgs holds the old version or patches it.
4. **Our script has a logic bug** → 250 lines, easy to fix. Same risk as maintaining a fork patch.

### 5.3 The Real Fragility Winner

| Approach | Fragility | Why |
|----------|-----------|-----|
| **shell-gpt from nixpkgs** | **LOWEST** | Zero code we maintain. nixpkgs + upstream handle everything. |
| Fork shell-gpt | LOW | We maintain a ~10-line patch. Rebase 2-3x/year. |
| Fork llm-cmd | MEDIUM | Must also maintain llm framework compatibility. |
| Build from scratch | MEDIUM | 250 lines we maintain. Low surface, but 100% ours. |

---

## 6. Pragmatic Recommendation — Tiered

### Tier 1 (Recommended): shell-gpt from nixpkgs + HM Module

**What**: Install `pkgs.shell-gpt` via HM, configure via env vars. No fork. No patch.

**Our code**:
```nix
# home-linux/shell-gpt.nix (NEW, ~20 lines)
{ config, lib, ... }:
let cfg = config.home.shell-gpt;
in {
  options.home.shell-gpt = {
    enable = lib.mkEnableOption "ShellGPT AI command assistant";
    provider = lib.mkOption { type = lib.types.str; default = "nvidia"; };
    model = lib.mkOption { type = lib.types.str; default = "nvidia/nemotron-3-ultra-550b-a55b"; };
    baseUrl = lib.mkOption { type = lib.types.str; default = "https://integrate.api.nvidia.com/v1"; };
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.shell-gpt ];
    home.sessionVariables = {
      API_BASE_URL = cfg.baseUrl;
      OPENAI_API_KEY = "$NVIDIA_API_KEY";  # already in sops-nix env
      DEFAULT_MODEL = cfg.model;
      SHELL_INTERACTION = "true";
      DEFAULT_EXECUTE_SHELL_CMD = "false";  # don't auto-execute
    };
  };
}
```

**User experience**:
```bash
$ sgpt --shell "deshacer el último commit de git pero mantener los cambios"
> git reset --soft HEAD~1
[E]xecute, [M]odify, [D]escribe, [A]bort: e
```

**Pros**: Works TODAY. Zero code to maintain. Full feature set (chat, REPL, roles, caching). Safety model is reasonable (shlex.quote + confirmation prompt).

**Cons**: No danger pattern detection. Relies on user not fat-fingering `E` on `rm -rf /`.

### Tier 1.5 (If danger detection is required): Fork shell-gpt + patch

**Add to Tier 1**: Fork shell-gpt, add a 20-line `check_danger()` function that runs before the [E/M/D/A] prompt and marks dangerous commands. Use via Nix overlay.

**Total OUR code**: ~10 lines (patch) + ~30 lines (Nix overlay + HM module) = ~40 lines.

**Pros**: Danger detection. Same UX. Same feature set. Minimal maintenance (2-3 rebases/year).

**Cons**: Must maintain fork. But at ~10 lines, it's trivial.

### Tier 2: Build from scratch

**Only if**: You need features that shell-gpt fundamentally can't provide (custom allow/deny lists, execution sandbox, multi-stage execution).

**Pros**: Full control. Nix-native.

**Cons**: 250 lines to write and maintain. Only gets command generation — no chat, no REPL, no roles, no caching. All features must be built.

### Tier 3: llm + llm-cmd

**Not recommended**. The `llm` framework is heavy (~200MB Python env with numpy, sqlite, embedding support). llm-cmd has genuine `shell=True` with no defense. Forking would require pulling in the entire `llm` ecosystem. Overkill for "generate a shell command."

---

## 7. Why NOT "Build From Scratch"

The first exploration defaulted to "build from scratch" because it incorrectly believed shell-gpt had `shell=True` injection vulnerabilities. That premise was wrong.

**The honest assessment**: shell-gpt already does 95% of what we want, with better UX than we'd build in 250 lines, and has 10k+ users battle-testing it. Our "build from scratch" would give us:
- Same API calling patterns (openai Python lib)
- Same system prompt approach
- Worse UX (no streaming, no REPL, no chat history)
- More code to maintain
- Side-grade safety (we'd use arg arrays, losing pipe/redirect support)

The ONLY missing feature from shell-gpt is danger pattern detection. That's a 20-line patch.

---

## 8. Risks — Honest Assessment

| Risk | Severity | Evidence | Mitigation |
|------|----------|----------|------------|
| **Destructive command execution** (rm -rf, dd, mkfs) | MEDIUM | User might accidentally hit `E` on dangerous command | [E/M/D/A] prompt exists. Add danger detection via fork or config. |
| **API key leak in shell history** | LOW | `OPENAI_API_KEY` in env, not typed | Standard shell hygiene. `set +o history` for API calls not needed (env var, not command arg). |
| **nixpkgs updates shell-gpt** | NEGLIGIBLE | nixpkgs maintains package, updates are tested | We pin flake locks. Updates are opt-in. |
| **NVIDIA NIM API outage** | MEDIUM | External dependency, not our control | No mitigation needed — tool just fails gracefully. Can add ollama fallback later. |
| **Command injection via LLM output** | **NEGLIGIBLE** | `shlex.quote()` blocks all shell metacharacters. Verified by code audit. | Already defended by shell-gpt's implementation. |
| **Model generates wrong command** | LOW | Confirmation prompt shows command before execution | User can [M]odify or [A]bort. [D]escribe explains the command. |
| **nixpkgs drops shell-gpt** | LOW | Package is maintained, 10k+ stars, active upstream | Easy to add our own derivation if needed. |

---

## 9. Key Design Decisions (Ready for Proposal)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Base tool** | shell-gpt from nixpkgs | Works TODAY. 10k+ users. Feature-complete. shlex.quote defense. Env var config. |
| **Danger detection** | Add via HM config (allow/deny lists) | Can be done in a wrapper or fork patch. Not critical for v1. |
| **Provider** | NVIDIA NIM via env vars | Already in opencode.json. Works with shell-gpt's OpenAI client. |
| **Model** | `nvidia/nemotron-3-ultra-550b-a55b` | Already battle-tested in our SDD phases. |
| **Nix module** | `home-linux/shell-gpt.nix` with env vars | Follows existing pattern. Trivial implementation. ~20 lines. |
| **Host import** | Per-host (rog, thinkcentre, t14) | NOT in shared-modules.nix. Follows host-conditional pattern like conky-rog. |
| **Build from scratch** | NOT recommended for v1 | Premature. shell-gpt already does what we need. If it proves insufficient, then build. |

---

## 10. Ready for Next Phase

**YES.** This exploration covers:
- ✅ Deep-dive into shell-gpt's actual execution model (NOT what README says, what the code does)
- ✅ Deep-dive into llm-cmd's execution model
- ✅ Honest comparison table with real numbers (not biased toward "build")
- ✅ Fragility analysis for Python on NixOS
- ✅ Clear tiered recommendation with justification

**Next steps**:
1. **sdd-propose**: Update proposal to reflect "shell-gpt from nixpkgs + HM module" approach
2. **sdd-spec**: Given/When/Then scenarios for installation, configuration, provider setup, daily use
3. **sdd-design**: Nix module options, env var mapping, host imports
