---
description: Generate ultra-compressed commit message in Conventional Commits format
trigger: /caveman-commit
---

Read the skill file at ~/.config/opencode/skills/caveman-commit/SKILL.md and generate a terse commit message.

CONTEXT:
- Staged changes: !`git diff --cached --stat 2>/dev/null || echo "(no staged changes)"`
- Current branch: !`git branch --show-current 2>/dev/null || echo "(not a git repo)"`

TASK:
1. Analyze the staged changes (if any) or ask user what changes to describe
2. Generate a Conventional Commits message following the skill rules:
   - Subject: `<type>(<scope>): <imperative summary>` (≤50 chars ideal, 72 max)
   - Body: only when "why" isn't obvious from subject
   - No fluff, no AI attribution, imperative mood
3. Output the message in a code block ready to use with `git commit -m "..."` or paste

Return only the commit message, no extra commentary.
