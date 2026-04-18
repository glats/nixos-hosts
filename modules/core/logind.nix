{ ... }:

{
  services.logind.settings.Login = {
    HandlePowerKey = "poweroff";
    HandleSuspendKey = "suspend";
    HandleHibernateKey = "hibernate";
    HandleLidSwitch = "ignore";
  };
}
