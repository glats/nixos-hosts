# Providers configuration for shared opencode
# Imports base providers (nvidia, github-copilot, opencode-go)
# activeProviderName is threaded from the HM option so any host can
# override the active provider tier without editing this module.
{ lib ? throw "providers.nix must be imported with lib"
, activeProviderName ? "opencode-go"
,
}:

import ./providers-base.nix { inherit lib activeProviderName; }
