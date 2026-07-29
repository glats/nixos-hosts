# Providers configuration for shared opencode
# Imports base providers (nvidia, github-copilot, opencode-go)
# and merges extra providers (groq, cerebras, mistral, etc.) when present.
# activeProviderName is threaded from the HM option so any host can
# override the active provider tier without editing this module.
{
  lib ? throw "providers.nix must be imported with lib",
  activeProviderName ? "opencode-go-medium",
}:

let
  base = import ./providers-base.nix { inherit lib activeProviderName; };
  extras =
    if builtins.pathExists ./providers-extra.nix then
      import ./providers-extra.nix { inherit lib; }
    else
      { extraProviders = { }; };
in
base // { inherit (extras) extraProviders; }
