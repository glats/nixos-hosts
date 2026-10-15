# Private candidate login prepared; user authentication pending

Authorization #3983 reopens the stopped rog cycle for a fresh user-performed
native login and subsequent bounded proof. This worker prepared the environment
only. No OAuth, native TUI/server, SDK setup, model prompt or MCP canary was run.
The new candidate database does not exist yet; no production account/session
database, credential file or decrypted environment file was read or copied.

## User terminal command

Run this in the user's own terminal on rog:

```sh
(umask 077; cd /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/project && /nix/store/3khlkav73hhzg98kw6m37mi4svsg5shz-gentle-v4-private-login/bin/opencode-private --standalone)
```

In the native TUI, enter `/connect`, select **OpenAI**, and choose an offered
OAuth/device-code method rather than entering a key in chat. Complete the flow
personally in the browser/native interface. Authentication labels can vary;
do not assume the current documentation's example label is this binary's label.
Do not submit a model prompt or choose a replacement model. Once connected,
exit the TUI and tell the parent `ya conecté la cuenta`, without a token, code,
account-database dump or screenshot containing authorization details.

Official V2 sources verify `--standalone`, `/connect`, provider method selection
and SQLite account storage:

- https://opencode.ai/v2/docs/cli
- https://opencode.ai/v2/docs/cli/providers

Context7 was also consulted for these V2 concepts. No V1 API/configuration was
used. OAuth itself can contact the provider and the native user process can
initialize configured integrations; that is not a model prompt or proof of
organic delegation. No shared service command is required.

## Reified isolation and candidate provenance

Scratch root is `gentle-v4-live-rog/login.ibv0_799` under the approved temporary
directory. Scratch directories are mode 0700 and ordinary files mode 0600.
The immutable SDK dependency symlink points only to the Nix store.

Actual `homeConfigurations.rog.extendModules` forces `home.homeDirectory` to
the scratch `home`, using the existing module pattern from
`shared/opencode/home-launcher.test.py`. No HM activation was run. It builds the
existing compiled HM Gentle wrapper and regenerates JSON and the owned asset
tree. The separate scratch-only compiled ELF native launcher targets the actual
`.opencode2-unwrapped`, not the production shell wrapper or shared service.

| Route | Reified destination |
|---|---|
| HOME | Scratch `home` |
| XDG_CONFIG_HOME / OPENCODE_CONFIG_DIR | Scratch `home/.config/opencode-v2` |
| XDG_DATA_HOME / database | Scratch `home/.local/opencode-v2/data` / `opencode.db` |
| XDG_CACHE_HOME / XDG_STATE_HOME / TMPDIR | Scratch runtime `cache` / `state` / `tmp` |
| Project configuration | Disabled by the existing V2 environment |
| GH_CONFIG_DIR | Scratch `home/.config/gh`, never production gh accounts |
| Relay / registry Go executable | Absolute private HM compiled `gentle-ai-v2-managed` wrapper |
| Runtime discovery | Existing private symlink to actual pinned native CLI |

The launcher removes inherited inline/config-file override variables. It sets
private HOME before plugin/shell children; the existing host-config plugin can
scrub XDG_CONFIG_HOME to private `HOME/.config`, and the actual Gentle wrapper
restores all candidate V2 roots. MCP declarations and policy were not loosened
or disabled. GitHub MCP wrappers use gh's native account lookup; the explicit
private GH_CONFIG_DIR means they cannot borrow production gh accounts. Their
authentication, like other MCP readiness, is unverified and may be unavailable.
No secret exports were sourced to compensate. Engram/RTK/host-config and the
tagged relay/registry plugins remain the actual candidate assets.

Read-only version probes returned **opencode v2.0.14** and **gentle-ai 4.0.0**;
SDK dependencies are **2.0.14**. ELF headers, compiled private-root constants and
absolute relay/registry wrapper references were checked. No provider catalog,
authentication-state API or account-database inspection was invoked.

The selected profile is `openai-medium`. All 13 managed ODD/JD/review roles are
present; additional existing general/neutral/writing agents remain unchanged.
Orchestrator, explore, verify, JD judges and all four review lenses/refuter use
`openai/gpt-6.1-sol`; worker, JD fix and review validator use
`openai/gpt-5.6-luna`. The retired profiles and NVIDIA repair are taken from the
current candidate configuration, not restored or substituted.

Public metadata and check receipts are retained in scratch:
`candidate.nix`, `metadata-final.json`, `source-identity.json`, and
`preparation-proof.json`. All 31 owned entries matched repaired fingerprint
`80c3f4be999c87e20eccb35521d5fdcae5c0e33a8ac0b98ffb52282987aea4fd` at preparation
start. During concurrent validation, `flake.nix` changed from expected
`f7d40c6f21e4b6a6a5fcd263221a2bdcd81a294e8198bd0af93ca7ca967029ba` to
`0f7106d8fcfed91402cdae76940ebc30c6a60556a129d2fd29cf1eefcd5da19d`.
The candidate runtime metadata reevaluated identically after that change.
This worker did not edit that file, the reviewed fingerprint, product source,
Git index or refs. Final whole-source fingerprint equivalence is not claimed;
the parent must reconcile concurrent tracking before acceptance.

## Later bounded cycle — not executed

The initial six-provider-request allocation was an unenforced proposal, not a
user-imposed numeric limit or a verified runtime guarantee. Six logical stages
can require multiple model turns. The stages remain orchestrator, worker,
resume/persistence readback, risk lens, refuter and validator; a separate verify
invocation was not included in that initial allocation.

`live-budget-check.md` documents actual pinned 2.0.14 hooks and a typed scratch
guard proposal: 20 session request preparations, independently 20 model HTTP
middleware admissions, and a 15-minute deadline/watchdog. Those units do not
bound every raw network exchange or guarantee a monetary ceiling. The private
HTTP transport override, guard loading and watchdog are not yet installed or
validated. Disclose the final budget and verify those controls before model
execution; do not present pure counter tests as organic enforcement proof.

Actual task admission, role-bound receipts and count/cancellation mechanisms
must be checked before the first model request. A tool-use continuation consumes
the agreed budget, not an additional free allowance; the proposed guard refuses
automatic provider retries. If the native runtime cannot enforce the bound, stop and report that
limitation rather than calling the allocation a proven hard cap. Stop at the
first failure with no automatic retry, model fallback or version change. No
receipt will be forged and prompt text is not behavioral persistence proof.
The user-authenticated account may lack access to either configured model;
login success alone does not establish model/catalog/quota compatibility.

This worker intentionally did not edit shared tasks/progress while other Linux
and native Mac validation workers were active. Engram #3989 records preparation.
No deployment, activation, service restart, account copy, publication or organic
success is claimed. The next action belongs to the user: native manual login.
