# macOS host configuration for mact2
# Darwin system modules and home-darwin modules are imported by mkDarwinHost builder.
# This file contains only mact2-specific settings.
{ pkgs
, inputs
, self
, primaryUser
, javaVersion
, lib
, host
, ...
}:
{
  # Host-specific settings
  networking.hostName = host;
}
