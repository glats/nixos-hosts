# opencode-provider-allowlist Specification

## Purpose

One central Nix provider allowlist consumed by the V1 and V2 runtimes.

## Requirements

### Requirement: Central Six-Provider Allowlist

The system MUST define a single allowlist of six provider IDs (`opencode`, `opencode-go`, `anthropic`, `openai`, `github-copilot`, `nvidia`) in `shared/opencode/providers-base.nix`. Both runtimes MUST derive their provider surface from this list.

#### Scenario: Allowlist is singular and complete [hosts: rog, thinkcentre, t14, macm5]
- GIVEN the shared provider base evaluated
- WHEN its allowlist is inspected
- THEN it contains the six IDs and no other provider ID
- AND a change to the list drives both `disabled_providers` and V2 policies

### Requirement: V1 disabled_providers Derivation

V1 MUST derive `disabled_providers` from the allowlist as the curated deny set of catalog providers outside the six (`cerebras`, `cloudflare-ai-gateway`, `cloudflare-workers-ai`, `cohere`, `groq`, `kilo`, `mistral`, `openrouter`, `google`). `nvidia` MUST remain a non-catalog provider, never listed as disabled.

#### Scenario: Deny set re-derived from allowlist [hosts: rog, thinkcentre, t14, macm5]
- GIVEN the V1 configuration generated
- WHEN its `disabled_providers` is inspected
- THEN it equals the nine curated catalog IDs and `nvidia` is absent

### Requirement: V2 Ordered Deny-Allow Policies

V2 MUST emit `experimental.policies` denying `*` first, then allowing each of the six IDs in order, with last match winning.

#### Scenario: Ordered policy emitted [hosts: rog, thinkcentre, t14, macm5]
- GIVEN the V2 runtime configuration generated
- WHEN its `experimental.policies` is inspected
- THEN `deny *` precedes six `allow` entries, one per allowed ID

### Requirement: NVIDIA Preservation

The `nvidiaProvider` declaration, the dormant `nvidia` profile, `allProviders`, and the `NVIDIA_API_KEY` export MUST remain unchanged.

#### Scenario: NVIDIA surface untouched [hosts: rog, thinkcentre, t14, macm5]
- GIVEN the change applied
- WHEN the NVIDIA declaration, profile, and export are diffed against the baseline
- THEN they are byte-identical

### Requirement: Empirical Deny Smoke

The change MUST pass a runtime deny smoke: `opencode2 models` lists only the six allowed providers, and `opencode2 run -m groq/<model> "hi"` is rejected.

#### Scenario: Deny enforcement proven at runtime [hosts: rog]
- GIVEN V2 running on rog
- WHEN models are listed and a groq model is run
- THEN only the six providers appear and the groq request is denied

### Requirement: OpenCode Env Export Reduction

`shared/opencode.nix` MUST export only `OPENCODE_API_KEY` and `NVIDIA_API_KEY`. The ten no-consumer exports (`cerebras`, `openrouter`, `mistral`, `cohere`, `gemini`, cloudflare token and account id, `kilo`, `huggingface`, `aihubmix`) and `GROQ_API_KEY` MUST be removed from OpenCode shell init.

#### Scenario: Export surface shrinks [hosts: rog, thinkcentre, t14, macm5]
- GIVEN the pruned shared OpenCode environment definitions
- WHEN its sops-backed exports are inspected
- THEN only `OPENCODE_API_KEY` and `NVIDIA_API_KEY` remain and `GROQ_API_KEY` is absent

### Requirement: GROQ Re-home Dependency

`GROQ_API_KEY` removal MUST NOT ship without the `groq-voice-dictation` change exporting it (in `linux/home/groq-dictation.nix`, registered in `linux/home/shared-modules.nix`). The sops secret `opencode/groq_api_key` MUST remain unchanged.

#### Scenario: Dictation owns the Groq credential [hosts: rog, thinkcentre, t14]
- GIVEN the `groq-voice-dictation` export has landed
- WHEN the dictation module shell init is inspected
- THEN `GROQ_API_KEY` is exported there and the sops secret is untouched
