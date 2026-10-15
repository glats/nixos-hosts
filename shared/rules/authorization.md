## Repository authorization boundary

Explicit user instructions and repository policy override upstream ODD defaults.
A task document, signed task, successful check or review receipt is not consent
to stage, commit, push, create a pull request, merge, activate, restart services,
upgrade runtimes or access credentials. Honor the actual authorized scope; when
any of those actions is excluded or not authorized by repository/user policy,
leave it pending and return evidence instead of performing it. Prompt guidance
is not an enforceable Git or delivery guard; use the runtime's real permissions.

Preserve historical OpenSpec artifacts. Before moving unfinished work to ODD,
obtain explicit selection and a handoff with history links, stable task IDs,
observed evidence and remaining gates. Never bulk-convert or mark work complete.
