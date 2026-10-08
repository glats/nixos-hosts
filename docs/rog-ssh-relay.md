# On-Demand rog-to-macm5 SSH Relay

This integration is source-configured but disabled until the runtime headers
and restriction policy are provisioned. It does not change routes, TUN,
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

## Provisioning gate

Do not put plaintext credentials in this repository, a Nix expression, a
launchd plist, process arguments, or logs. Before enabling either module,
provision the planned `secrets/shared/ssh-relay.yaml` through the existing
sops workflow, with separate per-host credentials. The server restriction file
must contain the native wstunnel YAML `restrictions` list and exactly one
anchored `!ReverseTunnel` Authorization rule permitting protocol `Tcp`, port
`22220`, and CIDR `127.0.0.1/32`. The client header file must contain the
native `Authorization: ...` header line. The default system-sops secret remains
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
promotion transaction. The encrypted file and its values are intentionally
absent.

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
The live policy remains `/run/ssh-relay/restrictions.yaml`; the sops-managed
source is never used as the live policy file. `relay-policy revoke` installs
the explicit deny-all policy after the same stop proof.

After authorized provisioning, set `services.ssh-relay.enable = true` and the
runtime-only `restrictionsFile`/`headersFile` options in the corresponding host modules,
then independently verify the native macOS client, TCP443 endpoint, DNS, TLS
pin, SSH host key, outage recovery, cancellation, and listener isolation.
Those runtime gates have not been run by this configuration-only work unit.

## Package provenance

The package downloads only the official GitHub v11.0.0 release assets; it does
not compile Rust or fall back to a source build. Supported assets are
`wstunnel_11.0.0_linux_amd64.tar.gz` (SHA256
`9708a99717b5a951453c2ff7c14c25d3418d02ca7fcb96fdb382a8f2083bab5e`) and
`wstunnel_11.0.0_darwin_arm64.tar.gz` (SHA256
`150e439c8b94859154903d71313b4c0b313ac9ccf99437af42573134e5051dc4`). The
Linux derivation checks `--version` and `--help`; Darwin asset inspection and
derivation evaluation pass, but native execution remains pending.

## Operational controls

On macOS, run `relayctl on`, `relayctl status`, or `relayctl off` manually.
The launch agent has `KeepAlive = false` and `RunAtLoad = false`; wstunnel owns
its capped native reconnect backoff. A fatal wstunnel exit is degraded state,
not an automatic recovery guarantee. `status` reports relay and SSH evidence as
unknown until a separate authorized end-to-end probe exists.

Rollback is the removal of the two host imports/configuration blocks, the
optional nginx vhost, the SSH alias, and the pinned package/helper. No secret
file was created by this change, so credential revocation remains a later
provisioning operation.
