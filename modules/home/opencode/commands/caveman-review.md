---
description: Generate ultra-compressed code review comments
trigger: /caveman-review
---

Read the skill file at ~/.config/opencode/skills/caveman-review/SKILL.md and generate terse code review comments.

TASK:
1. If user provided code/diff/PR content, analyze it
2. If no content provided, ask user to share the diff or file to review
3. Generate review comments following the skill rules:
   - Format: `L<line>: <severity> <problem>. <fix>.`
   - One line per finding
   - Use severity prefixes: 🔴 bug, 🟡 risk, 🔵 nit, ❓ q
   - Concrete fixes, not vague suggestions
   - Exact line numbers and symbol names in backticks
4. Output comments ready to paste into PR

SEVERITY LEGEND:
- 🔴 bug — broken behavior, will cause incident
- 🟡 risk — works but fragile (race, missing null check, etc.)
- 🔵 nit — style, naming, can be ignored
- ❓ q — genuine question, not suggestion

Return only the review comments, grouped by file if multi-file review.
