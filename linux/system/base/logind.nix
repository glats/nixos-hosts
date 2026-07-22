{ ... }:

{
  services.logind.settings.Login = {
    HandlePowerKey = "poweroff";
    HandleSuspendKey = "suspend";
    HandleHibernateKey = "hibernate";
    HandleLidSwitch = "ignore";
    # Explicitly disable logind-level idle locking.
    # Without this, systemd-logind can auto-lock sessions via IdleAction,
    # which would lock the screen even when hypridle is stopped.
    IdleAction = "ignore";
  };
}
