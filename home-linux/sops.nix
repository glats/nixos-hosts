{ config, ... }:

{
  imports = [ ../shared/sops.nix ];

  # Linux-specific secrets
  sops.secrets."openfang/telegram_bot_token" = {
    mode = "0400";
  };
  sops.secrets."openfang/api_key" = {
    mode = "0400";
  };
}
