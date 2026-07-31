{
  self,
  system,
  primaryUser,
  host,
  lib,
  ...
}:
{
  system.defaults = {
    CustomUserPreferences."com.apple.dock" = {
      mru-spaces = false;
    };
    dock = {
      autohide = true;
      show-recents = false;
    };
  };
}
