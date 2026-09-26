# Delta for gentle-ai-declarative-runtime

## MODIFIED Requirements

### Requirement: Provider Credential Exports Remain Stable

`shared/opencode.nix` MUST export only `OPENCODE_API_KEY` and `NVIDIA_API_KEY`. The ten no-consumer exports MUST be removed. `GROQ_API_KEY` MUST be removed from OpenCode shell init and re-homed to the `groq-voice-dictation` module.

(Previously: required every existing export, including Groq and Cerebras, to remain byte-identical.)

#### Scenario: OpenCode exports shrink to active surface [hosts: rog, thinkcentre, t14, macm5]
- GIVEN the pruned shared OpenCode environment definitions
- WHEN its exports are inspected
- THEN only `OPENCODE_API_KEY` and `NVIDIA_API_KEY` remain
- AND `GROQ_API_KEY` and the ten no-consumer exports are absent

#### Scenario: Dictation receives the re-homed Groq credential [hosts: rog, thinkcentre, t14]
- GIVEN the `groq-voice-dictation` change has shipped its export
- WHEN the dictation module shell init is inspected
- THEN `GROQ_API_KEY` is exported there
- AND the `opencode/groq_api_key` sops secret is unchanged
