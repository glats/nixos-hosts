# Decision review

Use this when finished work leaves decisions that belong to the user: a document with a
"Decisions for the human" section, campaign questions, or items marked as needing a decision.

## Flow

1. Collect every open decision from the documents and the campaign (`campaign status`). Read the
   sources yourself; never ask the user to read first.
2. Open with an executive brief: what was produced, where it lives, how many decisions are open,
   and what each group unblocks. Short enough to read in under a minute.
3. Close decisions one at a time, in dependency order. For each one give a brief of at most four
   lines: what it is, why it matters, the options with their cost, and your recommendation.
4. Ask with the native `question` tool, one question per call, recommended option first and
   labelled as such, each option with its consequence. Then stop and wait. Free text stays
   allowed; a question about the decision is a request for information, not an answer.
5. Record every answer at once, in the user's own words: `campaign answer --question <id>` for a
   campaign question, otherwise a note through `campaign answer` and the project's logbook.
   Silence, momentum or a passing test never counts as a decision.
6. After each answer say what it unblocks. When your own earlier advice has a catch the documents
   reveal, say so before asking.
7. Finish with the decisions taken, the ones still open, and the next safe step. Items that
   depend on an open decision wait; do not select them.

## Rules

- One decision per question. Never bundle choices so the user answers several at once.
- Never decide for the user, and never present a recommendation as already chosen.
- Privileged runs, signing, publishing and spending stay the user's, even when the recommended
  option is obvious.
- A decision the user already gave is applied, not asked again.
