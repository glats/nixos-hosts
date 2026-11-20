# Subscription plan evaluation

Objective: decide with measured data whether one Claude plan at about $100 is worth more than three plans at about $20 (Anthropic Pro, OpenAI Plus, Ollama Cloud).
Branch: feat/model. Delivery: documentation only, no code. Test runner: none. Related: `odd/tasks/provider-quota-balance.md` (tiered chains, quota baseline).

## Specs

S1. Measurement window: three full weekly cycles from the 2026-11-19 baseline, read at each Anthropic weekly reset (Thu 2026-11-26 09:00, 2026-12-03 09:00, 2026-12-10 09:00 local). The conclusion is written on 2026-12-10 after the third reading. Assumption: Anthropic and OpenAI reset weekly and Ollama monthly (2026-12-19), so Ollama is compared pro rata ($60 per 30 days is about $14 per week).

S2. Readings are manual ("mide"): read the three usage pages with the browser (https://claude.ai/chats#settings/usage, https://chatgpt.com/settings/usage, https://ollama.com/settings) and append one row group per provider to the `## Readings` table, taken just before each weekly reset so they show the peak of the cycle. `ollama.com/api/balance` is a valid direct source for Ollama. No quota reader is built before the conclusion.

S3. Per cycle and provider, record: peak used percent of the weekly window, the 5-hour window peak when visible, and whether the window reached 100% before its reset.

S4. Per cycle, count the work stops, taken from the swarm notifications and from the user's report for interactive sessions: `Provider limit on <agent>` (one provider limited) and `All providers are limited` (nothing could continue). Source for swarms: `jq -r 'select(.title|test("limit";"i"))|[.time,.severity,.title]|@tsv' ~/.local/state/gastown/swarm/<project>/notifications.jsonl`.

S5. Per cycle, record how many tasks needed the big tier (Opus or Astra) because the mid tier (Sonnet, Sol, DeepSeek) did not deliver, from the user's report.

S6. Decision rules, applied on 2026-12-10 over the three cycles (thresholds are assumptions to confirm with the user before the conclusion):
- Keep three plans: nothing stopped work for lack of a provider (`All providers are limited` at most once) and every provider's peak was at least 30% in some cycle.
- Move to one $100 Claude plan: Anthropic reached 100% in at least two cycles and `All providers are limited` happened at least twice, meaning the other two plans did not absorb the load; OR the big tier was needed often enough that mid-tier fallbacks cost quality.
- Drop one $20 plan: a provider peaked under 30% in all three cycles.
- Rebalance first, spend nothing: Anthropic reached 100% while OpenAI and Ollama stayed under 60%. Route more work to them (chains, tiers) and re-measure one cycle before upgrading.

S7. A single $100 Claude plan removes the fallback to other providers; the conclusion states that risk next to the numbers.

## Tasks

| ID | Spec | Route | Status | Evidence |
| --- | --- | --- | --- | --- |
| E1 | S2, S3 | inline | pending, on request ("mide") | baseline in `provider-quota-balance.md` |
| E2 | S4 | inline | pending | notifications per swarm |
| E3 | S5 | inline | pending | user report |
| E4 | S6, S7 | inline | pending, due 2026-12-10 | conclusion section below |

## Readings

(Append each reading here as `date | provider | window | peak used | limit reached | resets`. The 2026-11-19 baseline is in `odd/tasks/provider-quota-balance.md`.)

## Conclusion

(Written on 2026-12-10.)

## Log

L1 (2026-11-20, user, verbatim): "me pregunto como puedo medir y ver si vale la pena emjor tener un claude por 100 dolares en vez de 3 provedores por 20 cada uno"

L2 (2026-11-20, user, verbatim): "ya ese sera nuestro proximo plan vale? que ahcemos para sacar una conclusion cuanod lo que hay que mirar occurra?"

L3 (2026-11-20): plan created from the measurement proposal: metrics (peak percent per window, limit events, tokens, big-tier need), a conclusion date after three weekly cycles, and the four decision rules in S6. Thresholds 30% and 60% and "two cycles" are assumptions.
