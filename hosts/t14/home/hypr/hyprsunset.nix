# T14 Hyprsunset configuration.
#
# This module overrides the upstream omarchy hyprsunset.conf with the
# user's t14-specific progressive blue-light filter profile.
#
# Upstream's default is a single identity=true profile at 07:00 (no
# tint).  T14 enables a progressive warming schedule:
#   - 07:00  identity=true  (no tint in the morning)
#   - 18:00  temperature=4500K  (warm tint at sunset)
#   - 19:30  temperature=4000K
#   - 21:00  temperature=3500K
#   - 23:00  temperature=3000K  (max warmth at bedtime)
#
# The source hyprsunset.conf has two identical `profile { time=07:00
# identity=true }` blocks (a copy-paste artifact).  Both are preserved
# here for fidelity.
#
# Implementation: we use the same mechanism as upstream omarchy
# (xdg.configFile + systemd.user.services), not the HM
# services.hyprsunset module.  Using the HM module would conflict
# with upstream's manually-defined systemd unit at the same path.
# This pattern matches the upstream approach.
{ ... }:

{
  xdg.configFile."hypr/hyprsunset.conf".text = ''
    # Makes hyprsunset do nothing to the screen by default
    # Without this, the default applies some tint to the monitor
    profile {
        time = 07:00
        identity = true
    }

    profile {
        time = 07:00
        identity = true
    }

    profile {
        time = 18:00
        temperature = 4500
    }

    profile {
        time = 19:30
        temperature = 4000
    }

    profile {
        time = 21:00
        temperature = 3500
    }

    profile {
        time = 23:00
        temperature = 3000
    }
  '';
}
