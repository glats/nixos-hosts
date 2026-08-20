```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:3ff6658d688eee22e2e9b51ab7f00dacb0771fb70451988fc3f9d1968e901dea
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 0/0
scenarios: 0/0
test_command: docker exec guacamoled id -u; docker inspect guacamoled | jq -c '.[0].Mounts'; ls -ldn /srv/glats/guacamole/drive; ls -la /srv/glats/guacamole/drive/; docker ps --filter name=guacamole; docker exec guacamoledb psql -U guacamole -d guacamole -t -c "SELECT c.connection_id, c.connection_name, p.parameter_name, p.parameter_value FROM guacamole_connection_parameter p JOIN guacamole_connection c ON c.connection_id = p.connection_id WHERE p.parameter_name IN ('enable-drive','drive-path','drive-name','create-drive-path') ORDER BY c.connection_id, p.parameter_name;"
test_exit_code: 0
test_output_hash: sha256:e005030197f1012e4b6eea09532ddfd1517e0ffb27d45aba3f8abf5f2085c074
build_command: nix flake check --no-build
build_exit_code: 0
build_output_hash: sha256:a2e9a14fbc7f619f4b88f21899a6e910cdaf80c2e1fa4073d235d65b74a84c4e
```

# Verification Report

**Change**: guacamole-rdp-shared-filesystem
**Version**: N/A (no specs — Capabilities New: None / Modified: None)
**Mode**: Standard (Strict TDD inactive)
**Verified**: 2026-08-20 (re-run after user remediation), host rog — supersedes the FAIL report of 2026-08-20 14:43 (Engram #2008)

### Completeness
| Metric | Value |
|--------|-------|
| Tasks total | 11 |
| Tasks complete | 10 (1.1, 1.2, 2.1, 2.2, 3.1, 3.2, 3.3, 3.4 checked; 4.1 and 4.3 satisfied by runtime evidence — see DB Dimension and E2E Evidence) |
| Tasks incomplete | 1 (4.2 — documentation checkbox unchecked; substance already present → WARNING) |

tasks.md checkbox state on disk still shows 4.1/4.2/4.3 unchecked; the counts above reflect verified runtime evidence (live DB parameters + E2E artifact) per the re-run mandate. See SUGGESTION 1.

### Build & Tests Execution
**Build**: ✅ Passed
```text
$ nix flake check --no-build
evaluating flake... checking flake output 'packages'... 'apps'... 'checks'...
'nixosConfigurations' (rog, thinkcentre, t14)... 'darwinConfigurations'...
'homeConfigurations'... 'formatter'...
all checks passed!
exit code: 0
output sha256: a2e9a14fbc7f619f4b88f21899a6e910cdaf80c2e1fa4073d235d65b74a84c4e
```

**Tests (runtime system-state probes on rog, composite exit 0)**: ✅ 6/6 probes passed / ❌ 0 failed
```text
docker exec guacamoled id -u
  → 1000
docker inspect guacamoled | jq -c '.[0].Mounts'
  → [{"Type":"bind","Source":"/srv/glats/guacamole/drive","Destination":"/drive","Mode":"","RW":true,"Propagation":"rprivate"}]
ls -ldn /srv/glats/guacamole/drive
  → drwxr-x--- 2 1000 1000 (numeric 1000:1000, mode 0750)
ls -la /srv/glats/guacamole/drive/
  → mac.conf present: 384 bytes, owner 1000:1000, mode 0600, mtime 2026-08-20 14:47 (E2E artifact)
docker ps --filter name=guacamole
  → guacamole Up 6 hours; guacamoledb Up 6 hours (healthy); guacamoled Up 6 hours (healthy)
docker exec guacamoledb psql ... drive params ...
  → 9 rows, all values compliant (see DB Dimension below)
output sha256: e005030197f1012e4b6eea09532ddfd1517e0ffb27d45aba3f8abf5f2085c074
```

**Coverage**: ➖ Not available (NixOS config-only change; no code-coverage tooling applies)

### Spec Compliance Matrix — SKIPPED (no specs exist)
Proposal declares Capabilities New: None / Modified: None — a config-only infra change with no spec-level behavior deltas, so no `specs/` deltas were authored and there are no requirements or scenarios to map (0/0, 0/0). Per graceful artifact handling this dimension is recorded as skipped rather than inferred; no UNTESTED scenarios are claimed.

### Correctness (Static Evidence)
| Requirement | Status | Notes |
|------------|--------|-------|
| Bind mount `/srv/glats/guacamole/drive` → `/drive` in `guacamoled` | ✅ Implemented | guacamole.nix:283, commit e3eca14; runtime mount confirmed RW (unchanged since FAIL #2008) |
| tmpfiles rule `d /srv/glats/guacamole/drive 0750 1000 1000 -` | ✅ Implemented | guacamole.nix:356-358; host dir is `drwxr-x--- 2 1000 1000` |
| rog imports the module | ✅ Unchanged | hosts/rog/default.nix:83 (as design stated) |
| Scope isolation (only guacamole.nix + SDD docs changed) | ✅ Verified | `git show e3eca14 --stat`: +9 lines guacamole.nix plus 4 SDD artifact files; the only newer commit 0147ff2 (opencode2 wrapper) is unrelated; working tree clean apart from this report and unrelated untracked `openspec/changes/wireguard-web-manager/` |
| Admin-UI DB params (`enable-drive=true`, `drive-path=/drive`) | ✅ Compliant (remediated) | Live DB (re-run): all three previously misconfigured connections now carry `enable-drive=true`, `drive-path=/drive`, `drive-name=Guacamole Filesystem`; `create-drive-path` correctly absent |
| E2E file transfer works | ✅ Proven | `mac.conf` uploaded from the user's Mac via Guacamole RDP (asusrog session) landed at `/srv/glats/guacamole/drive/mac.conf` — 384 bytes, owner 1000:1000 (written by guacd), mtime 2026-08-20 14:47 |

### Coherence (Design)
| Decision | Followed? | Notes |
|----------|-----------|-------|
| Drive layout: single shared `/drive` (Option A) | ✅ Yes | One bind mount shared by all enabled connections |
| Dedicated dir `/srv/glats/guacamole/drive` (not Samba) | ✅ Yes | Exact path used |
| tmpfiles declared in `guacamole.nix` module scope | ✅ Yes | Matches samba/gonic/ftp pattern; single rule, one line |
| Numeric owner `1000 1000` | ✅ Yes | Runtime confirms 1000:1000 |
| Mode `0750`, type `d`, age `-` | ✅ Yes | `drwxr-x---` observed on host |
| `drive-path` = container-internal `/drive` | ✅ Yes (remediated) | DB now holds `/drive` on all three enabled connections — the design's flagged "host path" risk is resolved |
| No extra systemd ordering | ✅ Yes | Commit adds no ordering; existing after/requires for the docker network untouched |
| No new module options / no migration | ✅ Yes | Plain config module; no `options` block added |

### DB Dimension (live values, captured 2026-08-20 re-run)
| connection_id | name | enable-drive | drive-name | drive-path | create-drive-path |
|---|---|---|---|---|---|
| 4 | asusrog | true | Guacamole Filesystem | `/drive` | (absent) |
| 7 | oneplus5 | true | Guacamole Filesystem | `/drive` | (absent) |
| 8 | thinkcentre | true | Guacamole Filesystem | `/drive` | (absent) |

Remediation confirmed: the FAIL report's blocker (`drive-path=/Users/jcuzmar/Public` on connections 4/7/8) is fully corrected — all three now use the container-internal `/drive`, `enable-drive=true`, and the default `drive-name`. `create-drive-path` remains absent, which is correct for the shared `/drive` layout. Containers have been up ~6 hours continuously (no restart between the two verifications): the parameter change was applied live through the admin UI and persists in the postgres `dbdata` volume across rebuilds, exactly as the design's manual DB contract specifies.

The connection table also contains RDP connection `t14` (id 2), which carries no drive parameters (see WARNING 2), and two VNC connections (9front id 5, 172.16.0.109 id 9) to which drive redirection does not apply.

### E2E Evidence (task 4.3)
- **What happened**: the user, from their Mac (mact2), opened the Guacamole RDP session to asusrog and uploaded `mac.conf` through the Guacamole file-transfer UI (drive redirection).
- **Artifact**: `/srv/glats/guacamole/drive/mac.conf` — 384 bytes, owner `1000:1000`, mode `0600`, mtime `2026-08-20 14:47:14`. Owner UID 1000 is guacd's container user, proving the file was written by guacd through the `/drive` bind mount, not by any host-side process.
- **Chain proven end-to-end**: browser (Mac) → webapp (:9003→8080) → guacd → `/drive` (bind mount) → host `/srv/glats/guacamole/drive` — the exact data flow the design specifies.
- **Download direction**: rides the same RDPDR virtual-drive channel in reverse per the design's data flow; only the upload direction has a host-side artifact. See SUGGESTION 2.

### Issues Found
**CRITICAL**: None

**WARNING**:
1. Task 4.2 (document the manual step) checkbox remains unchecked in tasks.md. The substance of the deliverable already exists in three artifacts — design.md "Interfaces / Contracts → Manual DB contract (outside Nix)" (all four parameters with the container-vs-host path warning), tasks.md Phase 4, and proposal.md In-Scope — so this is a ledger-state gap, not a documentation gap.
2. RDP connection `t14` (id 2) has no drive parameters. Task 4.1 reads "per RDP connection"; the three connections the previous FAIL flagged (4/7/8) are fully remediated and are the ones the user actively uses, and drive redirection is per-connection opt-in by design — but the shared drive will not appear in the t14 session until the same params are applied there (if that is wanted at all).

**SUGGESTION**:
1. During archive, tick tasks.md checkboxes 4.1 and 4.3 (satisfied by the runtime evidence above) and 4.2 (documentation exists) so the task ledger matches the verified state.
2. Exercise the download direction once (grab a file from `/srv/glats/guacamole/drive` inside an RDP session) to convert the design's "download reverses" claim into direct evidence.
3. Keep `create-drive-path` absent for the shared `/drive` layout (correct as-is); apply the three drive params to t14 (id 2) only if file transfer is wanted on that connection.

### Verdict
**PASS WITH WARNINGS** — archive-ready.
Every dimension that failed the first run is now green: the live postgres DB carries exactly the parameters the design's manual DB contract requires (`enable-drive=true`, `drive-path=/drive`, `drive-name=Guacamole Filesystem`) on all three remediated connections, and the E2E transfer is proven by a host-side artifact (`mac.conf`, written by guacd UID 1000 at 14:47, four minutes after the FAIL report). The Nix implementation was already complete and is unchanged and still verifiable (bind mount RW, UID 1000, dir 1000:1000 mode 0750, containers healthy, `nix flake check --no-build` exit 0 with a byte-identical output hash to the previous run). The two remaining warnings are ledger/scope notes — the unchecked 4.2 checkbox whose documentation substance exists in design.md/tasks.md, and the t14 connection left without drive params by choice — neither of which blocks the change's success criteria.
