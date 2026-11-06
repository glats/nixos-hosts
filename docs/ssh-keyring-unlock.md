# SSH authentication and GNOME Keyring

GNOME Keyring's native PAM module can unlock the login keyring during SSH
password authentication. This keeps GitHub CLI OAuth credentials encrypted at
rest and makes them available without an XRDP session or a new PAT.

The existing SSH PAM stack includes `pam_gnome_keyring.so` for authentication and
session startup. Public-key-only authentication does not supply a password to
that module, so it does not automatically unlock a locked keyring. Password
authentication can unlock it when the Linux account password matches the login
keyring password. A successful SSH login alone does not prove the unlock worked.

## Password-authenticated session

For a one-off password-authenticated connection, without changing the server or
the client's persistent configuration:

```console
ssh -t -o PubkeyAuthentication=no -o PreferredAuthentications=password rog.lan
```

Enter the Linux account password in the SSH client, never in chat or command
arguments. After login, confirm the collection state without reading secrets:

```console
busctl --user --auto-start=no --timeout=3s get-property org.freedesktop.secrets /org/freedesktop/secrets/aliases/login org.freedesktop.Secret.Collection Locked
```

`b false` means unlocked. A missing service, missing collection, or `b true`
requires further diagnosis; it does not by itself prove the password is wrong.
Keep the session open while testing GitHub CLI and the GitHub MCP servers.

The password/PAM flow was verified on rog with an unchanged Secret Service
owner, one control socket, and `gh api user --jq .login` returning `glats`.
This does not verify every account, MCP, or GPG signing. Graphical rofi behavior,
the existing SSH policy, and public-key automation are unchanged.

## No custom unlock daemon

The former shell-startup unlock helper has been removed. In GNOME Keyring 50.0,
`gnome-keyring-daemon --unlock` starts a daemon; it is not a client command for
unlocking the already-running instance. Do not use it as a retry command.

If duplicate daemons have displaced the control socket, obtain explicit approval
before reconciling them. Do not delete keyrings, reset their passwords, or restart
SSH to fix this. Native PAM handles the credential exchange; no custom control
protocol client or curses prompt is installed.

## Home Manager activation

Selecting the default GitHub account during activation remains best-effort.
`gh auth switch` gets five seconds to complete, followed by a two-second grace
period before forced termination. Failure or timeout prints a warning and
activation continues; the requested account may not have become active.

After unlocking the keyring, retry selection manually if needed:

```console
gh auth switch --hostname github.com --user glats
```

Use the account configured by `home.github.defaultAccount` on other hosts. This
limit prevents account selection from blocking activation; it does not bypass
SSO or suppress failures from other services.
