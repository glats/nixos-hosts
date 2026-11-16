---
name: gastown-kickoff
description: "Trigger: new gastown project, swarm init, kickoff, start a campaign on a repository, choose checks and agents. Build the exact init and start commands with verified checks, agents and an intent text."
license: Apache-2.0
metadata:
  author: "glats"
  version: "1.1"
---

## Activation Contract

Load when the user wants to point `gastown-run` at a repository. After kickoff, operate it with `gastown-orchestrator`.

## Hard Rules

- The swarm clones committed state only. Commit or tell the user what is left out.
- Every `--check` must be offline, deterministic and pass on the base today. Run each one inside the gate's own isolation (bwrap, cleared environment, no network, no USER or HOME, PATH limited to the tool packages), not in an interactive shell: a check that passes in your shell can fail every branch there. Never use checks that need root, network, devices or a VM: workers cannot run them.
- Credentials come from the user's environment (provider keys from their shell, `CLAUDE_CODE_OAUTH_TOKEN` for claude agents). Never print them and never use API-key billing.
- `swarm init` cannot be repeated on an existing project, so its checks are fixed. Prefer one stable project `check` entry point as the `--check`, letting rules grow inside the repository, over a list of individual tool commands.
- Always `--protect` the `check` entry point and every rule or tool configuration file it reads (linter, formatter, type checker, test runner settings). The gate rebuilds each branch from the worker's own files, so an unprotected rule can be relaxed instead of satisfied.

## Decision Gates

| Need | Choice |
|---|---|
| Planning quality | Strong Mayor (`claude:opus` or `claude:sonnet`); it only plans and dispatches. |
| Volume | Workers `opencode:ollama-cloud/<model>`, fallback list in order. |
| Cheap roles | Witness, refinery and deacon use the first worker model: keep it cheap. |
| Files the user is editing | `--protect <path>`; the gate rejects branches that touch them. |
| Resources unknown | The intent must tell the Mayor to ask the user before assuming any. |

## Execution Steps

1. Check the repo state and find the existing `check` entry point, test and lint commands. A project without a harness gets one first through `odd-project` (Delivery 0); do not start a feature campaign on bare checks.
2. Validate each check in a clean clone under the gate's isolation; set missing variables inline (for example ), ask for missing tools in the host's gastown tool packages, and drop checks that still fail.
3. Pick agents; run `gastown-run swarm check <p>` after init.
4. Write the intent: scope the team supports, what stays open to forks, which docs to read first, and an instruction to ask about resources.
5. Emit `swarm init`, `swarm check` and `campaign start` as one block.

## Output Contract

One copy-paste command block, the list of checks with how each was verified, the protected paths, and what the checks do not prove.
