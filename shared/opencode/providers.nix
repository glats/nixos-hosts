# Providers configuration for shared opencode
# Base providers (nvidia, opencode) live in providers-base.nix together
# with the routing profiles. activeProviderName is threaded from the HM
# option so any host can override the active provider tier without
# editing this module.
{ lib ? throw "providers.nix must be imported with lib"
, activeProviderName ? "opencode-go-medium"
,
}:

import ./providers-base.nix { inherit lib activeProviderName; }
