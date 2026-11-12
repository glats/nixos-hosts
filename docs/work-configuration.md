# Keep work packages in the private configuration

The public macOS configuration keeps its generic provider and model settings but
does not install the work-only package or register its provider. A separately
managed private flake imports the public configuration and supplies that module.
The public flake and its checks do not require access to a private repository.

## Choose the configuration source explicitly

Use the private flake for a macOS work rebuild. Using only the public flake selects
the generic configuration and will not retain work-only packages in that generation.
Do not switch an existing work host to that generic output unintentionally.

Before authorizing activation, evaluate the private outputs on the appropriate
platform, replacing the example path with the private checkout:

```console
nix eval '/path/to/private-layer#homeConfigurations.macm5.activationPackage.drvPath'
nix eval '/path/to/private-layer#darwinConfigurations.macm5.config.system.build.toplevel.drvPath'
```

These commands only evaluate configuration; they do not activate a generation.
Full macOS evaluation can require Darwin build tools because of existing
import-from-derivation dependencies. Focused Linux-side checks do not replace that
host gate.

## What remains unchanged

GitHub accounts, signing identities and private keys remain SOPS-managed runtime
inputs. Access to a private Git repository does not authorize SOPS decryption.
No host is activated by changing the public package boundary.

The private layer must replace the original public module explicitly rather than
append a second package. Its pinned public version must be updated separately when
publication is authorized. Tests that previously expected identical public/private
work-package membership must distinguish generic public settings from private
additions before that input is bumped.

The corporate CA stays local and ignored. The generic legacy filename pattern
continues to protect older extracted certificates without naming an employer.
Removing current literals does not remove earlier commits or historical artifacts;
history rewriting is a separate destructive operation, not part of this extraction.
