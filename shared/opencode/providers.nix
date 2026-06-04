# Providers configuration for shared opencode
# Imports base providers (nvidia, github-copilot, opencode-go)
{ lib ? throw "providers.nix must be imported with lib"
,
}:

import ./providers-base.nix { inherit lib; }
