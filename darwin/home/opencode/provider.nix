{
  pkgs,
  ...
}:

{
  home.opencode.activeProviderName = "anthropic-copilot";
  home.opencode.extraAllowedProviders = [ "kairos" ];
  home.packages = [ (pkgs.callPackage ../../../pkgs/kairos-cli { }) ];
  home.shell-gpt.model = "nvidia/nemotron-3.5-super-vl-120b-a12b";
}
