# Delta for opencode-routing-profiles

## MODIFIED Requirements

### Requirement: `openai-opencode-balanced` Retained; Legacy Preserved

`openai-opencode-balanced` MUST retain its current mapping. All non-replaced legacy names (`copilot-custom`, `nvidia`, `github-copilot*`, `openai-full/medium/light`, `opencode-go-*`) MUST remain selectable with unchanged mappings, except `gentle-orchestrator` MUST change from `opencode-go/glm-5.3-flash` to `opencode-go/kimi-k3` in exactly three tiers: `opencode-go-openai`, `high-volume`, and `openai-opencode-balanced` — `opencode-go/kimi-k3` being the user-selected best-capability model on the `opencode-go` catalog (amended 2026-09-10). Their provider MUST remain `opencode-go`; every other tier and phase MUST remain unchanged. Acceptance MUST require delegation, retry, gate, and no-early-exit orchestration checks; the earlier per-task cost-reduction target is superseded by this user decision (Kimi K3 is priced $3.00/$15.00 per M tokens versus Flash's $0.15/$0.50).

(Previously: gentle-orchestrator changed to `opencode-go/mimo-v2.5` with a measurably-lower-cost acceptance target.)

#### Scenario: Legacy set remains selectable [hosts: rog, thinkcentre, t14, mact2]
- GIVEN pre-change and candidate legacy profiles
- WHEN names and mappings are diffed
- THEN names are identical and only the specified rog-selected mapping differs
- AND `activeProviderName = "nvidia"` still resolves

#### Scenario: Kimi K3 passes guarded acceptance [hosts: rog]
- GIVEN rog selects `opencode-go-openai`
- WHEN representative orchestration checks run
- THEN Kimi K3 completes delegation, retry, gates, and final delivery without early exit
- AND the session runs with tool-call integrity across representative tasks

#### Scenario: Failed quality gate restores Flash [hosts: rog]
- GIVEN Kimi K3 fails any required orchestration check
- WHEN routing rollback is applied
- THEN `opencode-go/glm-5.3-flash` is restored for `gentle-orchestrator` in all three amended tiers
- AND all other host and phase mappings remain unchanged

#### Scenario: Non-active kimi-k3 tiers resolve when selected
- GIVEN `high-volume` or `openai-opencode-balanced` is selected as `activeProviderName`
- WHEN the tier phases are resolved
- THEN `gentle-orchestrator` resolves to `opencode-go/kimi-k3`
- AND all other phases keep their existing mappings
