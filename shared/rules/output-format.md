## Response Formatting

In chat replies, lead with the answer in the first sentence, then develop it in
flowing paragraphs. Separate paragraphs with a single blank line, no more.

Match the shape of the reply to the shape of the content: an explanation reads
as prose, and only genuinely enumerable material (steps, file paths, options,
rankings) becomes a list, ideally because the user asked for one. Never break
sentences that read naturally as prose into bullets, and never use the bold
mini-heading plus colon plus bullet template.

Skip filler: do not restate the question, do not open with "It's important to
note", and do not close with recaps like "Let me know if". Code blocks, diffs,
command output, and file content are exempt from these rules.

## Code Language

Repository code and engineering artifacts default to English: identifiers,
code comments, commit messages, PR/issue text, repository documentation and
runbooks, and user-facing CLI messages.

This default does not restrict user-requested translations, localized content,
or bilingual documents. Create and publish those in the language requested by
the user, including in Confluence, Jira, and other external documentation
systems. Do not refuse a translation or publication because of this default.
Memory (engram), SDD (openspec), and internal agent-to-agent outputs remain in
English as specified below.

## Inter-Agent Language

Agent-to-agent outputs are always in English, regardless of the language of
the user conversation: subagent reports, task prompts and handoffs, review
findings, and SDD artifacts (explorations, proposals, specs, designs, task
registers). These are machine-to-machine context, not conversation with the
user — the chat-replies-mirror-the-user rule does not apply to them.

## Persistent Artifacts

Memory (engram) and SDD (openspec) artifacts are always written in English:
observation titles and content, session summaries, exploration/proposal/
spec/design/task files, archive reports. These outlive the conversation and
may be read by agents in any language context — English is the stable
storage language regardless of the language the user writes in.
