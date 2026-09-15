# SOPS setup for a new host

This procedure describes the authorized, on-host SOPS steps for `macm5`.
Remote preparation may document the steps, but must not read, decrypt, rotate,
or write encrypted secret files without the host and authorization present.

## Host recipient

On the physical host, generate or verify the SSH host key and derive its age
recipient without displaying private material:

```text
sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''
nix shell nixpkgs#ssh-to-age --command ssh-to-age \
  -i /etc/ssh/ssh_host_ed25519_key.pub
```

An authorized maintainer adds the resulting recipient to `.sops.yaml` and to
only the required creation rules. Do not guess a recipient and do not commit
the output of a secret decryption command.

## Encrypted data and link identity

The host recipient and the dedicated `uuid_macm5` value must be staged by the
SOPS owner. The identity is not a copy of another device identity. The owner
must verify the encrypted diff and use `sops updatekeys` only for the approved
files. This change intentionally does not perform that operation.

After rotation, verify only ciphertext metadata and repository status:

```text
git diff --check
git status --short
```

Do not use `sops -d`, shell interpolation, logs, or diagnostic output that
could expose UUIDs. If the required recipient or authorization is unavailable,
stop and leave all existing records unchanged.

## Activation dependency

The first macm5 switch is blocked until the encrypted files are available to
the host and the native preflight passes. Follow `docs/macm5-migration.md` for
the non-secret checks and `docs/macm5-acceptance.md` for the release evidence.

## Recovery

SOPS changes are reverted through the reviewed Git revision and an authorized
ciphertext rotation. Do not recover by reusing a different device identity or
by removing an existing host record. A missing age key is an authorization
failure; stop and contact the maintainer.
