# Archify output policy

Archify is a pinned, offline-capable skill deployed to OpenCode and Claude Code
from the immutable Nix package. Use it only for an explicit request to create a
reviewable diagram or HTML artifact.

## Input and review rules

- Use only public, reviewed facts tied to a revision-pinned source.
- Do not include secrets, credentials, tokens, private addresses, hostnames,
  internal network topology, or other sensitive operational details.
- Write retained output only below `docs/artifacts/archify/`. That directory is
  ignored because generated artifacts are review material, not source.
- Do not generate output automatically, start a preview server, or open a
  browser. A request that lacks explicit approval or uses another destination
  must produce no artifact.

Diagrams and generated HTML are assistive documentation only. They are not
runtime behavior, deployment evidence, or verification proof; validation must
use package, activation, and CLI checks instead.

The managed environment sets `ARCHIFY_UPDATE_CHECK_DISABLED=1`, so Archify
does not perform update checks or runtime installation. Keep the packaged
`node_modules` tree intact and do not use `npx`, `npm install`, or mutable
installers at runtime.
