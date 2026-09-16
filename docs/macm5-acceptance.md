# macm5 native acceptance record

This redacted record documents the accepted native evidence for the physical
Apple Silicon host. Never include UUIDs, decrypted secret values, private keys,
or raw logs containing credentials.

## Authorization

- Host: `macm5`
- Architecture: `aarch64-darwin`
- Git revision:
- Native operator: physical macm5 operator
- Maintainer approver: maintainer authorization recorded in the retirement request
- Approval timestamp: 2026-09-16
- Known-good generation: recorded on macm5; the generation identifier is intentionally not copied here

## Gate results

- [x] Physical macm5 deployment completed successfully.
- [x] SOPS decrypted the macm5 runtime configuration on the host.
- [x] `linkctl` was running on macm5.
- [x] The local proxy served a public Cloudflare issuer.
- [x] rog logged authenticated `[macm5]` VLESS connections, including `example.com`.
- [x] macm5 remained the only supported Darwin recovery path; mact2 was handed over and was not used as fallback.
- [x] Retirement evidence accepted: the authorized SOPS owner removed/re-encrypted `uuid_mact2` and rog was deployed; mact2 was enterprise-formatted, so direct failed-auth testing is unavailable.

## Evidence references

Use redacted command results or links to an approved evidence store:

- Evidence location: maintainer-approved native deployment evidence (redacted)
- Failure/recovery notes: no APFS or daemon-socket failure reported; macm5 generation retained on host. The inactive/formatted mact2 client plus deployed rog configuration is the accepted retirement evidence.
- Reviewer notes: evidence supports tasks 3.3 and 4.1; repository checks remain evaluation-only

The record contains only redacted native evidence. Retirement authorization was
explicitly granted after this evidence was accepted; mact2 is not a fallback.
