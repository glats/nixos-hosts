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
SOPS owner. The identity is not a copy of another device identity. This is an
admin-only procedure; do not perform it from an ordinary host account or from
an automated activation.

From an authorized admin workstation, after reviewing the exact recipient
diff, rotate only the four files consumed by macm5:

```text
cd /home/glats/.nixos
umask 077
uuidgen > "$TMPDIR/uuid_macm5"
sops secrets/shared/link-uuids.yaml
# Add uuid_macm5 using the generated value; do not change uuid_phone.
rm -f "$TMPDIR/uuid_macm5"
sops updatekeys -y secrets/shared/link-uuids.yaml
sops updatekeys -y secrets/shared/passwords.yaml
sops updatekeys -y secrets/user/opencode.yaml
sops updatekeys -y secrets/user/identities.yaml
```

The admin MUST keep the generated value out of shell history, command output,
logs, unmanaged temporary copies, backups, and Git. The `umask 077` temporary
file above exists only to paste the value into the SOPS editor and MUST be
removed immediately. In the editor, add only the scalar
`uuid_macm5` key; never copy or replace another device UUID. Verify only
ciphertext metadata and the encrypted diff before handing the change to the
macm5 operator.

After rotation, verify only ciphertext metadata and repository status:

```text
git diff --check
git status --short
```

Do not use `sops -d`, shell interpolation, logs, or diagnostic output that
could expose UUIDs. If the required recipient or authorization is unavailable,
stop and leave all existing records unchanged.

## Final retirement ciphertext procedure

After the redacted macm5 acceptance record is approved and the declarative
retirement is ready, an authorized SOPS owner MUST remove the scalar
`uuid_mact2` from `secrets/shared/link-uuids.yaml` and re-encrypt the file
for the remaining recipients. This repository session MUST NOT perform that
operation or read the encrypted file.

On the authorized admin workstation, review the recipient diff first, edit
the ciphertext with the SOPS editor, remove only `uuid_mact2`, save, and then
run:

```text
cd /home/glats/.nixos
sops secrets/shared/link-uuids.yaml
sops updatekeys -y secrets/shared/link-uuids.yaml
git status --short
```

The final encrypted file MUST retain `uuid_macm5` and `uuid_phone`, contain no
plaintext UUID in command output, logs, temporary files, backups, or Git, and
be encrypted only for the recipients declared by the post-retirement
`.sops.yaml`. Do not run `sops -d`; verify ciphertext metadata and the
encrypted diff only.

## Activation dependency

The first macm5 switch is blocked until the encrypted files are available to
the host and the native preflight passes. Follow `docs/macm5-migration.md` for
the non-secret checks and `docs/macm5-acceptance.md` for the release evidence.

## Recovery

SOPS changes are reverted through the reviewed Git revision and an authorized
ciphertext rotation. Do not recover by reusing a different device identity or
by removing an existing host record. A missing age key is an authorization
failure; stop and contact the maintainer.
