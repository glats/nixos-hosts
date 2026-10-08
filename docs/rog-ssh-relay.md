# On-Demand rog-to-macm5 SSH Relay

Both hosts now opt in at source level, with one encrypted macm5 publication
credential. Deployment and explicit runtime promotion are still required;
source preparation is not end-to-end readiness. It does not change routes, TUN,
`linkctl`, or the existing `tun.glats.org` backend.

## Intended path

`macm5` runs the manually controlled `relayctl on` primary-user launch agent
rendered by nix-darwin under `~/Library/LaunchAgents`. The agent
starts the pinned official precompiled Rust wstunnel 11.0.0 client, which makes verified WSS TCP443
connections to exactly `wss://relay.glats.org:443` and publishes only
`127.0.0.1:22` as `tcp://127.0.0.1:22220:127.0.0.1:22`. nginx terminates TLS and
proxies the isolated `relay.glats.org` WebSocket to rog's loopback port 4012.
The rog-only SSH alias is `macm5-relay` and uses the existing `macm5` host-key
record through `HostKeyAlias`; it does not disable host-key checking.

## Initial deployment and promotion

Do not put plaintext credentials in this repository, a Nix expression, a
launchd plist, process arguments, environment, or logs. The new
`secrets/shared/ssh-relay.yaml` holds one encrypted, independently revocable
macm5 publication credential under `ssh-relay/authorization`, encrypted only
for the existing admin, rog, and macm5 public age recipients. No existing
credential was decrypted or rotated. Normal host system-sops activation
materializes this input; do not manually decrypt it or copy token values.

After the reviewed source is committed and pushed, update each host's checkout
to that exact feature revision without discarding local changes. Deploy from
that checkout using the existing `nixos-build safe` command (it selects NixOS
or nix-darwin). Do rog first, then macm5. Do not deploy an older master revision
that still disables these endpoints. This runbook does not authorize an agent
to execute deployment or promotion.

On rog, the first deployment can report a failed `ssh-relay.service` start:
the enabled unit intentionally rejects the absent live restriction file. It
must never fall back to a permissive policy. If the safe workflow reports this
failure, confirm the new generation/unit and system-sops input were installed
before continuing; unrelated deployment failures require diagnosis first.
Only after that deployment, run:

```sh
sudo relay-policy stage /run/secrets/ssh-relay/authorization
sudo relay-policy apply
systemctl status ssh-relay.service --no-pager
```

Stage only creates the root-owned regular `0600` input at
`/run/ssh-relay-staging/authorization`; it does not operate systemd. Apply
masks/stops the dedicated unit, proves termination, installs the service-owned
`0600` policy at `/var/lib/ssh-relay/restrictions.yaml`, and restarts only when
prior unit intent was enabled. On any error, stop here: do not manually unmask
or bypass validation. A previously masked/revoked unit is not automatically
re-enabled by apply; that state requires a separate operator decision.
The live policy persists across rog reboot in a root-owned `0755` directory;
only the ssh-relay-owned `0600` file contains the credential. Runtime staging
and transaction locks remain under `/run`. After successful initial promotion,
the enabled service reads the existing policy at boot, allowing an already-on
Mac to reconnect through native retries without another rog stage/apply or Mac
`on`. A missing/bad policy still fails closed. No automatic live-policy updater
or credential rotation hook is needed for reboot recovery.

Before stopping or changing policy, the transaction durably creates a
root-owned `0600` non-secret marker at
`/var/lib/ssh-relay/promotion-pending`. The unit's negated path condition
inhibits boot/manual startup while this marker exists, even after a runtime
mask disappears. Failed/interrupted promotion keeps the marker; a successful
validated policy commit removes it before unmask/start. Unmask/start failures
restore it before compensating stop. Do not remove the marker manually.

On NixOS, the installed `/etc/systemd/system` unit takes precedence over a
runtime mask in `/run/systemd/system`, so a stopped unit may remain `loaded`
rather than `masked`. Promotion still requires `inactive` and an explicit
`MainPID=0`. The loaded-unit fallback additionally verifies the unique trusted
`0600` marker, the exact non-trigger negated marker condition in the installed
unit/drop-ins, and `NeedDaemonReload=no`. Missing/reset/trigger-only conditions,
changed configuration, or an unsafe/missing marker fail closed before reading
the staged token or replacing policy. Do not remove the marker or runtime mask
to work around an apply failure; deploy the corrected helper and retry apply.

To recover a failed/interrupted transaction, correct the input and rerun stage
and apply. Only after apply succeeds, if prior masked intent kept the unit
inactive and you explicitly want publication, run `sudo systemctl start
ssh-relay.service`. Never manually start or unmask after a failed apply.

On macm5, after deploying, run these commands as `juan` in the GUI user session
(not through sudo):

```sh
relayctl credentials stage /run/secrets/ssh-relay/authorization
relayctl credentials apply
relayctl on
relayctl status
```

The source secret is root-owned `0600` on rog and juan-owned `0600` on macm5.
Both use the default system-sops path; no automatic secret restart/reload or
live-file activation hook is configured. Staging creates missing credential
directories as private user-owned `0700` directories; it never repairs unsafe
existing parents. On Darwin only, source traversal accepts the canonical OS
directory `/private/var/run` with exactly root UID `0`, daemon GID `1`, and mode
`0775`. This exception does not apply to other directories or Linux.
macOS installs a manual agent with
`RunAtLoad = false` and `KeepAlive = false`; installing it is not an `on`.
Applying credentials while initially off keeps it off until the explicit `on`.

From rog, independently verify the final SSH hop:

```sh
ssh -n -T macm5-relay true
```

This probe must use the existing verified Mac host key and SSH identity; do not
accept a new key blindly or disable strict host-key checking. A running job or
successful status command alone does not prove end-to-end SSH. Native TLS,
revocation, long outage/sleep recovery, cancellation, and isolation still need
authorized runtime verification.

## Runtime credential boundary

The server restriction file
must contain the native wstunnel YAML `restrictions` list and exactly one
anchored `!ReverseTunnel` Authorization rule permitting protocol `Tcp`, port
`22220`, and CIDR `127.0.0.1/32`. The client header file must contain the
native `Authorization: ...` header line. On macm5, the default system-sops secret remains
at `/run/secrets/ssh-relay/authorization` with owner `juan` and mode `0600`;
it is not assigned a custom `path` symlink. Run the explicit user operation
`relayctl credentials stage /run/secrets/ssh-relay/authorization` to validate
that source and atomically copy only the URL-safe token into the regular
`0600` staging file at `/Users/juan/Library/Application Support/nixos/ssh-relay/authorization`.
The source may use a root-owned final sops symlink, but resolved ancestors and
the opened file must remain trusted; user-owned symlinks, writable ancestors,
hardlinks, Nix-store paths, and invalid tokens are rejected. Staging changes no
live header and invokes no launchd operation. Then run
`relayctl credentials apply`, which performs the existing stop-before-live
promotion transaction. Neither live file is managed directly by sops.

Missing, malformed, or empty restriction policy must prevent server startup;
`restrictions: []` is the explicit deny-all policy. Do not use permissive
fallbacks, UDP/SOCKS/HTTP rules, wildcard addresses, IPv6, or other ports.

Policy or credential revocation is not an automatic hot-reload transaction.
The safe operator sequence is: stop the dedicated relay service, verify its
process and active streams are gone, inhibit restart, replace and validate the
current policy/header files, then start only when validation succeeds. On any
failure, leave the service stopped. Use `restrictions: []` for the final
removal. Existing wstunnel hot reload behavior must not be treated as immediate
revocation.

For the ROG server, first run `relay-policy stage
/run/secrets/ssh-relay/authorization`. This validates the default system-sops
source and atomically writes the regular root-owned stage at
`/run/ssh-relay-staging/authorization`; it performs no systemd or live-policy
operation. Then run `relay-policy apply`, which performs the existing
stop-before-policy-replacement transaction and reads only that fixed stage.
The live policy remains `/var/lib/ssh-relay/restrictions.yaml`; the sops-managed
source is never used as the live policy file. `relay-policy revoke` installs
the explicit deny-all policy after the same stop proof.
Revocation retains both the durable inhibition marker and deny-all policy, so
reboot cannot restart publication after its runtime mask disappears. Only a
subsequent successful explicit apply can clear the inhibition; reboot does not
restore an old credential.

For subsequent input updates, deploy only the encrypted sops input and use the
same explicit stage/apply transactions; do not point the server at a watched
sops file. TLS uses hostname/system-CA verification, not a separate relay pin.
These runtime gates have not been run by this source-preparation work unit.

## Package provenance

The package downloads only the official GitHub v11.0.0 release assets; it does
not compile Rust or fall back to a source build. Supported assets are
`wstunnel_11.0.0_linux_amd64.tar.gz` (SHA256
`9708a99717b5a951453c2ff7c14c25d3418d02ca7fcb96fdb382a8f2083bab5e`) and
`wstunnel_11.0.0_darwin_arm64.tar.gz` (SHA256
`150e439c8b94859154903d71313b4c0b313ac9ccf99437af42573134e5051dc4`). The
Linux derivation checks `--version` and `--help`; Darwin asset inspection and
derivation evaluation pass. Bounded native Darwin execution and quiet retries
against an unavailable disposable endpoint passed; production connectivity,
installed launchd lifecycle, and long outage/sleep recovery remain pending.

## Operational controls

On macOS, run `relayctl on`, `relayctl status`, or `relayctl off` manually.
The launch agent has `KeepAlive = false` and `RunAtLoad = false`; wstunnel owns
its capped native reconnect backoff. A fatal wstunnel exit is degraded state,
not an automatic recovery guarantee. `status` reports relay and SSH evidence as
unknown until a separate authorized end-to-end probe exists.

Rollback is the removal of the two host imports/configuration blocks, the
optional nginx vhost, the SSH alias, and the pinned package/helper. If deployed,
first use `relayctl credentials revoke` as juan and `sudo relay-policy revoke`
on rog to stop and revoke live publication. Removing ciphertext or reverting
source alone does not revoke a live policy. This initial source unit can be
reverted independently by disabling the two host options and removing only its
relay secret declarations/ciphertext; preserve unrelated service credentials.
