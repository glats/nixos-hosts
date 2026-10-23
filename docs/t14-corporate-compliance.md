# t14 corporate compliance mode

`compliance-mode` selects the integrated corporate-compliance configuration on the t14 host. The current scope is Intune only. The command is implemented and tested locally; it has not been run on t14, and no activation, enrollment, or reboot proof exists yet.

## Quick path

1. Check the state (read-only, no root needed):

   ```sh
   compliance-mode status
   ```

2. Select the compliance-off specialisation (root, Linux):

   ```sh
   sudo "$(command -v compliance-mode)" off
   ```

3. Restore the ON configuration (root, Linux):

   ```sh
   sudo "$(command -v compliance-mode)" on
   ```

`sudo` resets `PATH`, so the command resolves the binary before elevating. This avoids installing a duplicate system package only for PATH.

## Details

| Topic | Decision |
|-------|----------|
| Scope | Intune only. No other corporate agent is integrated, and the tool does not claim control of missing Mac agents. |
| Runtime switch | `off` runs `<generation>/specialisation/compliance-off/bin/switch-to-configuration switch`; `on` runs `<generation>/bin/switch-to-configuration switch`. |
| Reboot selection | The tool rewrites only the `default` line of `/boot/loader/loader.conf` to the matching boot entry: `nixos-generation-N-specialisation-compliance-off.conf` for OFF, `nixos-generation-N.conf` for ON. The selected profile generation stays unchanged. |
| Paired parent | OFF and ON both use the selected profile generation N as the parent. The tool never scans historical generations or falls back to an unrelated ON generation. |
| Why not `nix-env` | `nix-env --set` on a specialisation path silently stores the parent store path, so the child cannot be selected as a profile generation. |
| Persistence limit | The boot default persists until the next native `nixos-rebuild switch` or `boot`, which rewrites the default to ON. Pruning the paired parent generation makes a later ON request refuse. |
| Persistence blockers | Refused before any change if `LoaderEntryDefault`, `LoaderEntryPreferred`, or `LoaderEntryOneShot` exists under the systemd loader vendor GUID, or if the EFI variables directory is missing. These variables are never cleared by this tool. |
| Unknown state | A missing marker, unreadable or unexpected `loader.conf`, missing boot entry, or runtime that matches neither the paired ON nor the OFF selection is reported as `unknown`. Unknown is never OFF or compliant. |
| Status exit code | `0` when the state is `on` or `off`; `1` when unknown or unreadable. |
| Failure and rollback | A failed runtime switch restores the original `loader.conf` bytes if the boot default is still the one this tool wrote. The runtime is not restored automatically, so the report says it is uncertain. If the selected profile or boot default moved during the operation, the tool does not overwrite it. |
| Concurrency | An exclusive lock serializes this tool's own mutations. It does not serialize other root tools. Do not run `compliance-mode` concurrently with `nixos-rebuild`, other bootloader writers, or profile operations: an external writer racing this tool is advisory only and is detected, not prevented. |
| Unenrollment | Not performed. Stopping services is not enrollment removal, and no anti-tamper control is bypassed. |
| Activation status | Source, tests and independent source verification are complete. No build, switch, reboot, or live boot-entry verification has been run on t14. |

## Checklist

- [ ] `compliance-mode status` reports `on` on a live ON system (pending live proof).
- [ ] `sudo "$(command -v compliance-mode)" off` switches runtime and boot default (pending live proof).
- [ ] After a reboot into the OFF entry, `status` reports `off` (pending live proof).
- [ ] `sudo "$(command -v compliance-mode)" on` restores ON and boot default (pending live proof).
- [ ] A native rebuild resets the boot default to ON, as documented (pending live proof).

## Next step

Independent source verification is complete, including the corrected boot-selection mechanism and its regression probes. Next, authorize a system build and inspect its deployment impact before any activation. Live switches, enrollment and reboot proof on t14 require separate explicit authorization.

## Test environment

On macOS, `TMPDIR` can resolve through the `/var` symlink to `/private/var`. Two unrelated packages (`internal/aiassets`, `internal/sshrelay`) then fail their path-trust checks on both the base and this change. Run the suite with a canonical temporary directory:

```sh
TMPDIR="$(cd "${TMPDIR:-/tmp}" && pwd -P)" go -C pkgs/nixos-scripts test ./...
```

This is a test-environment note only; the compliance-mode tooling does not depend on it.
