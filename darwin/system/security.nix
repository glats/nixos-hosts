{ self
, system
, primaryUser
, host
, lib
, ...
}:
{
  # touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  system.defaults.loginwindow = {
    GuestEnabled = false;
    DisableConsoleAccess = true;
  };

  # Configure macOS Application Firewall to allow SSH incoming connections
  system.activationScripts.firewallSSH.text = ''
    echo "> Configuring firewall for SSH access"
    # Allow sshd-keygen-wrapper through the Application Firewall
    # This is the binary that handles SSH connections on macOS
    SSHD_WRAPPER="/usr/libexec/sshd-keygen-wrapper"
    if [ -f "$SSHD_WRAPPER" ]; then
      /usr/libexec/ApplicationFirewall/socketfilterfw --add "$SSHD_WRAPPER" >/dev/null 2>&1 || true
      /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$SSHD_WRAPPER" >/dev/null 2>&1 || true
      echo "  - SSH ($SSHD_WRAPPER) allowed through firewall"
    fi
    # Also ensure /usr/sbin/sshd is allowed if it exists
    if [ -f "/usr/sbin/sshd" ]; then
      /usr/libexec/ApplicationFirewall/socketfilterfw --add "/usr/sbin/sshd" >/dev/null 2>&1 || true
      /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "/usr/sbin/sshd" >/dev/null 2>&1 || true
      echo "  - /usr/sbin/sshd allowed through firewall"
    fi
  '';
}
