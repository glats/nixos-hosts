# Correction to rule

Use this when the user corrects a delivery, rejects a branch, or the gate rejects the same
mistake twice. A correction kept as prose (a campaign learning, a steering reply, a line in the
worker contract) is advice a model may ignore; a check is a boundary it cannot pass.

## Flow

1. Name the mistake as an observable pattern, not as an incident: what code or behavior was
   wrong, where it can appear again, and the user's own words about why it is wrong.
2. Classify it in this order and stop at the first that fits:
   1. A lint or static rule in the project's own tooling (forbidden API, import boundary,
      naming, comment policy, banned dependency).
   2. A test that pins the behavior through the public interface.
   3. An architecture or API change that removes the mistake's possibility.
   4. Prose, only when none of the above can express it; say why.
3. Write the rule's failure message for an agent: what is wrong, why, and the root-cause fix.
   Never suggest a suppression or a workaround in the message.
4. Prove it: the rule fails on the rejected code, or a minimal reproduction of it, and `check`
   still passes on the base inside the gate's isolation.
5. Rule files and the `check` entry point are protected from workers, so the rule lands
   outside the swarm: propose the exact change to the user and apply it only after approval.
   Workers never relax or suppress a rule; a branch that tries is a rejection, not a fix.
6. Record the correction verbatim in the project's logbook with the rule that now enforces
   it, and drop any prose learning the rule replaces.

## Rules

- One correction, one rule. Never bundle unrelated patterns into one check.
- A rule that fires on code the user accepts is wrong; narrow it before landing it.
- The user decides strictness that costs speed or rewrites existing code.
