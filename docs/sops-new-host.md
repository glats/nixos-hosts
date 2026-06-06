# SOPS Setup for New Hosts

## Quick Reference: Adding a new host to sops

### 1. Post-install: Generate SSH host key

```bash
sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
```

### 2. Get age key from SSH host key

```bash
nix shell nixpkgs#ssh-to-age --command ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub
```

Copy the output (e.g., `age196hvyhz9nhwdxyadwj36umtssxqdhde80x3xyhkt9l9va73mtq3s3pxvnk`).

### 3. Update `.sops.yaml` in repo

Add the new host key to the `keys:` section:

```yaml
keys:
  - &host_t14 age196hvyhz9nhwdxyadwj36umtssxqdhde80x3xyhkt9l9va73mtq3s3pxvnk
```

Add to relevant creation rules:

```yaml
creation_rules:
  - path_regex: secrets/system/.+
    key_groups:
      - age:
          - *admin_glats
          - *host_rog
          - *host_thinkcentre
          - *host_t14
```

### 4. Copy admin key to new host

From an existing host (rog, thinkcentre):

```bash
scp /home/glats/.config/sops/age/keys.txt newhost:/home/glats/.config/sops/age/keys.txt
```

### 5. Re-encrypt secrets

On the new host:

```bash
cd ~/.nixos
for f in secrets/system/*.yaml; do
  sops updatekeys --yes "$f"
done
```

### 6. Enable sops in host config

In `hosts/<newhost>/default.nix`, uncomment:

```nix
../../modules/base/sops.nix
./secrets.nix
```

### 7. Rebuild

```bash
nixos-rebuild switch --flake .#<newhost>
```

## Important Notes

- **Admin key is required** for re-encryption. If lost, all secrets must be regenerated.
- **User secrets** (`secrets/user/*.yaml`) need a separate rule or `*host_t14` added.
- **Always backup** `.sops.yaml` and the admin key.
- **New host** must be installed and bootable before enabling sops (to generate SSH key).

## Current Hosts

| Host | Key |
|------|-----|
| admin_glats | `age1j4mxejwmktekgf24sju92ryayh5jlmv4ldxj62e2srwghpkpuujscct9lt` |
| rog | `age1q46qlf4kt0pc255nrl4r24m5hnvqwqf9wd8n6206f0zg95v6993qvd9cr8` |
| thinkcentre | `age1uhv0z8e04q2385wlrn0vgd237ts2exea375yr4yeqwx5v9zgw9esdg3rsn` |
| mact2 | `age1ngeetv5mnt8ax30tmm6799qs2779905v0jafpywuydrvw2sz7yds7rlp5z` |
| t14 | `age196hvyhz9nhwdxyadwj36umtssxqdhde80x3xyhkt9l9va73mtq3s3pxvnk` |
