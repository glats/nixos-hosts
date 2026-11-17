{ lib, ... }:

{
  home.opencode.activeProviderName = lib.mkDefault "anthropic-copilot";
  home.shell-gpt.model = "nvidia/nemotron-3.5-super-vl-120b-a12b";
}
