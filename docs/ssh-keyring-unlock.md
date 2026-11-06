# SSH login keyring unlock

Interactive Linux Zsh login sessions over SSH automatically offer to unlock the
existing GNOME login keyring when it is locked. This keeps GitHub CLI OAuth
credentials encrypted at rest without requiring an XRDP session or a new PAT.

The prompt runs before the shell is ready, not inside OpenCode. It uses systemd's
hidden terminal password input, not curses. Enter the **keyring password**, which
may differ from the SSH password. Empty input, Ctrl+C, or a 60-second timeout
skips unlocking without preventing SSH access. An already unlocked keyring is
silent. Nested non-login shells, commands passed to SSH, SCP, SFTP, and sessions
without a terminal do not trigger the startup hook. Graphical rofi and OpenCode's
existing no-curses protection are unchanged.

To retry from an interactive SSH terminal:

```console
ssh-keyring-unlock
ssh-keyring-unlock --help
```

The helper checks the login collection's lock state on the existing systemd user
bus. Secret Service may start through normal D-Bus activation. It does not create
a new bus, replace a daemon, read OAuth tokens, create keyrings, or modify stored
credentials. An absent login collection or unavailable user bus produces a
warning without asking for a password. The password is passed to
`gnome-keyring-daemon --unlock` only over stdin, never arguments, environment
variables, files, or logs. Unlocking is confirmed by checking the lock state
again; subprocess success alone is not considered proof.

Unlocking makes the collection available to other processes running as the same
user, including a graphical session. This does not authenticate a missing GitHub
account, bypass organization SSO rules, unlock other collections, or fix a
background service connected to a different D-Bus session. Git signing uses GPG
and remains a separate mechanism. Cancelling this prompt does not change existing
Git/MCP credential lookup behavior.

After applying the configuration, validate from a new SSH connection that the
prompt appears only when needed, cancellation still opens the shell, and GitHub
operations work in both the terminal and OpenCode without an XRDP session.
This user-assisted acceptance check is required; unit tests do not prove access
to the live credential store.

## Home Manager activation

Selecting the default GitHub account during activation is best-effort. The
`gh auth switch` command gets five seconds to complete, followed by a two-second
grace period before forced termination. Failure or timeout prints a warning and
activation continues; the requested account may not have become active.

After unlocking the keyring in your terminal, retry account selection manually:

```console
gh auth switch --hostname github.com --user glats
```

Use the account configured by `home.github.defaultAccount` on other hosts. This
limit prevents account selection from blocking activation; it does not resolve
an unavailable keyring, bypass SSO, or suppress failures from other services.
