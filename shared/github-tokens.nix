{
  # GitHub PATs used by both NixOS system services and Home Manager.
  # Imported from system and HM sops modules; per-scope ownership is added
  # by the system consumer.
  sops.secrets."github/personal_pat" = {
    sopsFile = ../secrets/shared/passwords.yaml;
    mode = "0400";
  };
  sops.secrets."github/work_pat" = {
    sopsFile = ../secrets/shared/passwords.yaml;
    mode = "0400";
  };
}
