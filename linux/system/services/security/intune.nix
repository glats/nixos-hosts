{ config, ... }:

{
  services.intune.enable = config.corporate.compliance.enable;
}
