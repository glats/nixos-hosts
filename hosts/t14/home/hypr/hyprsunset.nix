# T14 Hyprsunset -- progressive blue-light filter profile.
#
# omarchy-nix enables hyprsunset with a default identity=true profile at
# 07:00.  T14 overrides this with a progressive warming schedule using
# lib.mkForce via the Home Manager services.hyprsunset module.
#
# Profile:
#   - 07:00  identity=true  (no tint in the morning)
#   - 18:00  temperature=4500K  (warm tint at sunset)
#   - 19:30  temperature=4000K
#   - 21:00  temperature=3500K
#   - 23:00  temperature=3000K  (max warmth at bedtime)
{ lib, ... }:

{
  services.hyprsunset.settings.profile = lib.mkForce [
    { time = "07:00"; identity = true; }
    { time = "18:00"; temperature = 4500; }
    { time = "19:30"; temperature = 4000; }
    { time = "21:00"; temperature = 3500; }
    { time = "23:00"; temperature = 3000; }
  ];
}
