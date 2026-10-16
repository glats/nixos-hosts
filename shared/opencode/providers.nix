{
  lib ? throw "providers.nix must be imported with lib",
  activeProviderName ? "opencode-medium",
}:

import ./providers-base.nix { inherit lib activeProviderName; }
