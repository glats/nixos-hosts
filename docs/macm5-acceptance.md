# macm5 native acceptance record

This is a release-evidence template, not evidence that acceptance has passed.
Complete it on the physical Apple Silicon host and commit only the redacted
record after maintainer approval. Never include UUIDs, decrypted secret values,
private keys, or raw logs containing credentials.

## Authorization

- Host: `macm5`
- Architecture: `aarch64-darwin`
- Git revision:
- Native operator:
- Maintainer approver:
- Approval timestamp:
- Known-good generation:

## Gate results

- [ ] Fresh Determinate-only installation confirmed.
- [ ] `/nix` APFS mount confirmed.
- [ ] Determinate daemon socket and launchd services confirmed.
- [ ] `nix` and `darwin-rebuild` resolve from the expected PATH.
- [ ] Darwin evaluation and dry activation passed.
- [ ] Home Manager activation and generation listing passed.
- [ ] arm64 Homebrew resolves under `/opt/homebrew/bin`.
- [ ] SSH and Screen Sharing reachability passed.
- [ ] wsdd advertises `macm5`.
- [ ] Company-controlled LocalHostName remains `CLFTCLGV2FHWW0W`.
- [ ] `sing-box check` passed and rendered config is root-owned `0400`.
- [ ] Private-link direct CIDRs and safe direct default passed.
- [ ] Link-down behavior leaves ordinary connectivity usable.
- [ ] Git and generation recovery references recorded.

## Evidence references

Use redacted command results or links to an approved evidence store:

- Evidence location:
- Failure/recovery notes:
- Reviewer notes:

Acceptance is rejected if any gate is unchecked, if the evidence is not native
to macm5, or if the record contains secret material. Native acceptance does not
authorize retirement by itself; the retirement change requires its own review.
