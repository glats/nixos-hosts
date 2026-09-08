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

Everything that ships with the code is always in English, regardless of the
language the user writes in: identifiers, code comments, commit messages,
PR/issue text, documentation and runbooks, and user-facing CLI messages.
Chat replies mirror the user's language instead — do not force English on
conversation. Quoting user text verbatim is the only exception.
