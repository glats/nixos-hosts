{ pkgs, provider }:

assert (provider.home.packages or [ ]) == [ ];
assert (provider.home.opencode.extraAllowedProviders or [ ]) == [ ];
assert provider.home.opencode.activeProviderName == "anthropic-copilot";
assert provider.home.shell-gpt.model == "nvidia/nemotron-3.5-super-vl-120b-a12b";

pkgs.runCommand "work-package-boundary-check" { } ''
  touch $out
''
