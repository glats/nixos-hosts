## ODD Explore — MCP Research

When the request involves unfamiliar or changing external technology, exploration
(the `gentle-ai-explore` agent, or whoever explores in runtimes without it) should
research with MCP tools before analyzing repository code. Keep the research
proportional to the request:

- **context7**: fetch current library/framework documentation
- **github**: search for prior art, similar implementations, issues
- **exa**: web search for blog posts, best practices, migration guides

Verify APIs and versions with tools rather than relying on memory. Read code
second, then synthesize the findings for the ODD Explore step.
