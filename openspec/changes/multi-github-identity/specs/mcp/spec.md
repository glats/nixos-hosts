# Delta Spec: MCP Dual Server Entries

## Overview

Replace the single `github` MCP server entry with two named entries (`github-glats` and `github-jcuzmar`), each using a different GitHub PAT. Create platform-specific wrapper scripts that inject the correct token from sops secrets.

---

## ADDED Requirements

### MCP-REQ-1: github-glats MCP Entry

An MCP server entry named `github-glats` MUST be available on all hosts, using glats' GitHub PAT.

- **Token source**: sops secret `github/pat` (existing)
- **Wrapper binary**: `github-mcp-server-glats` — reads `github/pat` and exports `GITHUB_PERSONAL_ACCESS_TOKEN`
- **MCP config**: Added to `shared/opencode/mcps-base.nix`
- **Default**: Should be the active entry on Linux hosts (rog, thinkcentre, t14)

**Scenarios**:

```
SCENARIO: github-glats MCP entry connects on Linux
GIVEN  a Linux host (rog, thinkcentre, or t14)
  AND  the opencode MCP configuration is built
WHEN  the MCP client attempts to connect to github-glats
THEN  the connection MUST succeed
  AND  github API operations MUST authenticate as the glats user

SCENARIO: github-glats MCP entry connects on macOS
GIVEN  the macOS host (mact2)
  AND  the opencode MCP configuration is built
WHEN  the MCP client attempts to connect to github-glats
THEN  the connection MUST succeed
  AND  github API operations MUST authenticate as the glats user
```

### MCP-REQ-2: github-jcuzmar MCP Entry

An MCP server entry named `github-jcuzmar` MUST be available on all hosts, using jcuzmar's GitHub PAT.

- **Token source**: sops secret `github/pat_jcuzmar` (new, SEC-REQ-1)
- **Wrapper binary**: `github-mcp-server-jcuzmar` — reads `github/pat_jcuzmar` and exports `GITHUB_PERSONAL_ACCESS_TOKEN`
- **MCP config**: Added to `shared/opencode/mcps-base.nix`
- **Default**: Should be the active entry on macOS (mact2)

**Scenarios**:

```
SCENARIO: github-jcuzmar MCP entry connects on Linux
GIVEN  a Linux host (rog, thinkcentre, or t14)
  AND  the opencode MCP configuration is built
WHEN  the MCP client attempts to connect to github-jcuzmar
THEN  the connection MUST succeed
  AND  github API operations MUST authenticate as the jcuzmar user

SCENARIO: github-jcuzmar MCP entry connects on macOS
GIVEN  the macOS host (mact2)
  AND  the opencode MCP configuration is built
WHEN  the MCP client attempts to connect to github-jcuzmar
THEN  the connection MUST succeed
  AND  github API operations MUST authenticate as the jcuzmar user
```

### MCP-REQ-3: Linux MCP Wrapper Scripts

Linux host MUST have two wrapper scripts installed system-wide (not per-user) that read respective sops secrets and launch `github-mcp-server`.

- **github-mcp-server-glats**: reads `github/pat` → exports `GITHUB_PERSONAL_ACCESS_TOKEN`
- **github-mcp-server-jcuzmar**: reads `github/pat_jcuzmar` → exports `GITHUB_PERSONAL_ACCESS_TOKEN`
- **implementation**: Using `pkgs.writeShellScriptBin` (same pattern as existing `github-mcp-server-wrapped`)
- **File**: `modules/features/services/github-mcp-server.nix`

The existing single `github-mcp-server-wrapped` from `modules/features/services/github-mcp-server.nix` MUST be replaced or augmented with the two named wrappers.

**Scenarios**:

```
SCENARIO: Linux wrapper reads glats PAT
GIVEN  a Linux host with github-mcp-server-glats installed
WHEN  the wrapper script executes
THEN  it MUST read the sops secret at config.sops.secrets."github/pat".path
  AND  export it as GITHUB_PERSONAL_ACCESS_TOKEN
  AND  exec github-mcp-server

SCENARIO: Linux wrapper reads jcuzmar PAT
GIVEN  a Linux host with github-mcp-server-jcuzmar installed
WHEN  the wrapper script executes
THEN  it MUST read the sops secret at config.sops.secrets."github/pat_jcuzmar".path
  AND  export it as GITHUB_PERSONAL_ACCESS_TOKEN
  AND  exec github-mcp-server
```

### MCP-REQ-4: macOS MCP Wrapper Scripts

macOS MUST have two wrapper scripts (as user-level `home.packages`) that read respective sops secrets and launch `github-mcp-server`.

- **github-mcp-server-glats**: reads `github/pat` → exports `GITHUB_PERSONAL_ACCESS_TOKEN`
- **github-mcp-server-jcuzmar**: reads `github/token` (existing macOS token) → exports `GITHUB_PERSONAL_ACCESS_TOKEN`
- **implementation**: Using `pkgs.writeShellScriptBin` (same pattern as existing `github-mcp-server-wrapper.nix`)
- **File**: `home-darwin/github-mcp-server-wrapper.nix`

**Scenarios**:

```
SCENARIO: macOS wrapper reads glats PAT
GIVEN  macOS host (mact2)
WHEN  the github-mcp-server-glats wrapper executes
THEN  it MUST read the sops secret at config.sops.secrets."github/pat".path
  AND  export it as GITHUB_PERSONAL_ACCESS_TOKEN
  AND  exec github-mcp-server

SCENARIO: macOS wrapper reads jcuzmar token
GIVEN  macOS host (mact2)
WHEN  the github-mcp-server-jcuzmar wrapper executes
THEN  it MUST read the sops secret at config.sops.secrets."github/token".path
  AND  export it as GITHUB_PERSONAL_ACCESS_TOKEN
  AND  exec github-mcp-server
```

---

## MODIFIED Requirements

### MCP-REQ-5: MCP Base Config (MODIFIED)

Current `shared/opencode/mcps-base.nix` contains:
```nix
github = {
  type = "local";
  command = [ "github-mcp-server" "stdio" ];
  enabled = true;
};
```

After: Replace the single `github` entry with two entries:
```nix
"github-glats" = {
  type = "local";
  command = [ "github-mcp-server-glats" "stdio" ];
  enabled = true;
};
"github-jcuzmar" = {
  type = "local";
  command = [ "github-mcp-server-jcuzmar" "stdio" ];
  enabled = true;
};
```

- **File**: `shared/opencode/mcps-base.nix`
- Both entries MUST be enabled by default
- Platform-specific overrides (macOS vs Linux) SHOULD choose the correct default active entry

### MCP-REQ-6: macOS MCP Extra Config (MODIFIED)

Current `home-darwin/opencode/mcps-extra.nix` overrides the single `github` entry:
```nix
github = {
  type = "local";
  command = [ "github-mcp-server-wrapped" "stdio" ];
  enabled = true;
};
```

After: The override MUST be updated to match the new dual-entry scheme. This may mean:
- Removing the override entirely (if base config handles both)
- OR updating the override to reference the correct jcuzmar wrapper for macOS default

- **File**: `home-darwin/opencode/mcps-extra.nix`

---

## REMOVED Requirements

### MCP-REQ-7: Single github MCP Entry (REMOVED)

The single unqualified `github` MCP entry is REMOVED from `mcps-base.nix`.

(Reason: Replaced by two named entries `github-glats` and `github-jcuzmar`, each with its own token. This enables selecting the right identity per context without changing the MCP entry at runtime.)

---

## EDGE CASES

| E-1 | macOS jcuzmar token source | On macOS, the existing `github/token` (from `atlassian.yaml`) is jcuzmar's token. The new `github/pat_jcuzmar` is a different secret (from `passwords.yaml`). Both are jcuzmar tokens, but from different users/sources. Verify which one the macOS jcuzmar wrapper should use — likely the existing `github/token` to maintain compatibility. |
| E-2 | Wrapper script NixOS vs HM level | Linux wrappers are system-level (`environment.systemPackages` in `modules/features/services/`) while macOS wrappers are user-level (`home.packages` in HM module). The MCP config (`mcps-base.nix`) is HM-level. Ensure the wrapper scripts are available in PATH when HM builds the MCP config. On Linux, system-level packages are available to HM. |
| E-3 | Both MCP entries enabled simultaneously | The MCP client MUST support multiple github entries. Verify that the agent (opencode) handles multiple MCP entries with the same tool set without conflict. |
| E-4 | SSH-based MCP auth on macOS | On macOS, the github-mcp-server can also use SSH-based auth. The wrapper currently injects a token via env var, which takes precedence. If SSH keys are preferred, the wrapper could be bypassed. This is an intentional design choice (token-based for MCP). |
