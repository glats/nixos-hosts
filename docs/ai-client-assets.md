# Shared AI assets without an OpenCode dependency

`shared/ai-assets.nix` owns reusable skill sources, user rules and neutral skill
deployment. Enable `home.ai-assets.enable` to use them without enabling any client.
The OpenCode and Claude profiles enable this layer; enabling `home.codex.enable`
also enables it, including the shared command-line tools.

## Ownership

| Module | Responsibility |
| --- | --- |
| `shared/ai-assets.nix` | Ordered skill/rule sources and `~/.agents/skills` deployment |
| `shared/ai-tools.nix` | Engram, RTK, Gentle AI and PDF utilities |
| `shared/ai-mcps.nix` | Common MCP inventory and extra-server options |
| `shared/opencode/providers-base.nix` | OpenCode provider catalog and model routing |
| Client modules | Native config formats, permissions, hooks and compatibility assets |

`home.ai-assets.skillSources` is the source of truth. Sources are merged in order;
later sources replace earlier files at the same relative path. Local skills live
under `shared/assets/skills/` and are packaged by `pkgs/local-ai-assets`.

Codex discovers the neutral `~/.agents/skills` directory. OpenCode also discovers
it, while its existing `~/.config/opencode/skills` compatibility copy remains at
its original precedence. Claude keeps its `~/.claude/skills` copy. All three use
the same source list; no client directory is used as another client's source.
Disabling OpenCode does not disable shared skills or tools for the other clients.

The existing `ai-assets-reconcile` command manages the neutral directory with an
ownership manifest under `~/.agents`. It preserves unmanaged files and refuses
conflicting user edits. Deployment does not replace the directory with a symlink,
delete existing client skill directories, or run during evaluation.

## Verification and rollback

Run `python3 shared/ai-skills.test.py` and `python3 shared/ai-tools.test.py` for
client-independent evaluation. `python3 shared/opencode/asset-ownership.test.py`
exercises actual packaged consumer trees against temporary directories, including
retry, rollback, user-edit refusal and unmanaged-file preservation. Never run host
activation merely to test reconciliation.

Evaluate shared changes on Linux and Darwin separately. Rolling back the Nix
configuration restores previous client behavior without implicitly deleting
`~/.agents`; retained neutral skills remain until explicitly reconciled or retired.
Model choices, client permissions and MCP wire formats are not changed here.
