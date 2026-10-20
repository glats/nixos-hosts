{ pkgs, ... }:

{
  home.opencode.quotaPlugin = pkgs.callPackage ../../../pkgs/opencode-quota-patched { };
}
