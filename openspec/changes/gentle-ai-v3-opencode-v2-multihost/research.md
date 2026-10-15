{
  "schemaName": "gentle-ai.sdd-research/v1",
  "revision": 1,
  "change": "gentle-ai-v3-opencode-v2-multihost",
  "outcome": "blocked",
  "request": "Investigate transport first (selected explicitly: Investigar transporte primero).",
  "questions": [
    "Does local pkgs/gentle-ai-assets/v2-plugins/opencode-review-transport.ts satisfy the v3.7.0 CLI message, environment, receipt, artifact and schema contracts without bypassing immutable authority or admission checks?",
    "Does native V2 unsupported status also block the repository relay opencode-transport invocation, or is that invocation supported distinctly?",
    "What minimum compatibility changes or unresolved blockers affect local SDD result and skill registry plugins with SDK 2.0.14?",
    "Which exact non-destructive Linux and Darwin tests validate review roundtrip and real delegation, and what cannot be proven statically?"
  ],
  "requested_source_classes": ["documentation", "open-web"],
  "admission": {
    "schemaName": "gentle-ai.sdd-research-capability/v1",
    "outcome": "denied",
    "observed_exact_grants": {"documentation": [], "open-web": []},
    "reason": "The authoritative executor instruction explicitly grants neither requested evidence class. The lower-priority launch request cannot expand those grants. Persistence tools are not evidence grants.",
    "required_recovery": "The parent must relaunch under an authoritative executor capability declaration granting each requested class and its exact tools. Repeating grants only in the user launch request cannot repair admission."
  },
  "sources": [],
  "validated_claims": [],
  "contradictions": [],
  "uncertainty": [
    "All four questions remain unanswered by admitted evidence.",
    "Exploration context was read but is not admitted as a source or renewed compatibility proof.",
    "No external documentation, web, GitHub source, local implementation evidence, or runtime research execution was accessed after denial.",
    "Loaded phase contracts describe required fields but expose no executable research or preproposal validator. This recovery record is not a claim of native schema admission."
  ],
  "freshness": {"recorded_on": "2026-10-02", "source_accessed_at": null, "status": "No evidence collected"},
  "context_references": {
    "exploration_openspec": "openspec/changes/gentle-ai-v3-opencode-v2-multihost/exploration.md",
    "exploration_engram": 3579,
    "retained_intent_engram": 3586
  },
  "product_choices": {
    "authority": "Non-authoritative research record of the supplied orchestrator handoff",
    "confirmed": ["Target v3.7.0", "Single OpenCode V2 stack on all hosts", "Preserve SDD", "Retire V1 only after proof"],
    "pending": ["Transport and plugin compatibility solution; do not infer adapter compatibility"]
  },
  "proposal_ready": false
}
