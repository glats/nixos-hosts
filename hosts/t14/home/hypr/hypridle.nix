# T14 Hypridle overrides — idle lock timing tuned for the laptop.
#
# Omarchy provides a baseline hypridle config; t14 may need shorter
# timeouts for the built-in panel.  This module extends (not replaces)
# the omarchy listener list by adding a local override via extraConfig
# once omarchy's service has set up its listeners.
{ ... }:

{
  # Keep omarchy's hypridle service intact; no t14-specific override needed
  # yet.  The defaults (2.5 min lock, 5.5 min dpms off) are reasonable for
  # a laptop screen.  This file is reserved for future tuning.
}