# oneplus5 LAN SSH mesh runbook

`oneplus5` is a non-Nix host. This procedure is manual: the Nix flake does
not deploy, activate, or modify the phone. Perform it from a local console or
an already trusted session and record only redacted results.

## Enrollment

Confirm that the phone's local private identity is the `oneplus5` source
identity and that its public fingerprint matches `shared/ssh/lan-mesh.nix`.
Never copy a private key into the repository, SOPS, or another host.

Add these four exact Nix-source public lines to the phone user's
`~/.ssh/authorized_keys` for `glats`:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGX9n6Xva9Lpuf4Fn4rTqLl+3zbfSN2jzJQW7V54J1mu juan@CLFTCLGV2FHWW0W-lan
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID47wBmPxBXhRq8uxOABpd+G72Gyizn+hDU/B5Z6xAkT glats@rog-lan
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSehpAzNhKa87/oag3V60HqcmO4/ix6IbOjyXEQM8s6 glats@thinkcentre-lan
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILjmQmDCgrLLPpd9dpvWnB2Uqi25kTvj9Bycp0rKQt+R glats@t14-lan
```

Back up the current file before merging. Keep unrelated keys only when their
owner and purpose are known. Remove duplicates, set ownership to `glats`,
mode `600` on the file, and mode `700` on `.ssh`. Repeating the edit must not
duplicate lines or alter comments.

Configure these four aliases in the phone user's SSH config. All use the
phone's local identity, never a target identity:

```sshconfig
Host rog
    HostName rog.local
    User glats
    IdentityFile ~/.ssh/id_ed25519_lan
    IdentitiesOnly yes
Host thinkcentre
    HostName thinkcentre.local
    User glats
    IdentityFile ~/.ssh/id_ed25519_lan
    IdentitiesOnly yes
Host t14
    HostName t14.local
    User glats
    IdentityFile ~/.ssh/id_ed25519_lan
    IdentitiesOnly yes
Host macm5
    HostName CLFTCLGV2FHWW0W.local
    User juan
    IdentityFile ~/.ssh/id_ed25519_lan
    IdentitiesOnly yes
```

Do not weaken host-key verification, authorize root, or change password
policy. Verify peer host keys against the independently supplied records.

## Evidence and drift review

Record the date, registry revision, four authorized-key comments, permissions,
and redacted output from `ssh -G rog`, `ssh -G thinkcentre`, `ssh -G t14`, and
`ssh -G macm5`. After host keys are verified, run:

```text
ssh -o BatchMode=yes rog true
ssh -o BatchMode=yes thinkcentre true
ssh -o BatchMode=yes t14 true
ssh -o BatchMode=yes macm5 true
```

Compare the authorized lines and alias blocks with the registry during every
drift review. The phone remains manually managed even when they match.

## Emergency revocation

1. Remove the compromised source record from `shared/ssh/lan-mesh.nix` and
   deploy the resulting peer lists to all affected Nix targets.
2. Remove the exact compromised line from the phone's
   `~/.ssh/authorized_keys`, preserving a redacted backup, then recheck modes.
3. End active sessions authenticated by that identity where practical.
4. From the affected source, prove rejection with
   `ssh -o BatchMode=yes <peer> true` for every affected target and record only
   non-secret results.
5. Restore access only through a newly generated, locally verified public key
   and a new reviewed registry record. Never restore the revoked line.

This documents enrollment and revocation only; it does not claim phone
enrollment, the twenty-connection matrix, native `macm5` activation, or a
revocation drill has been completed.
