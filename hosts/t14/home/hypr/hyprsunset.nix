{ lib, ... }:

{
  services.hyprsunset.settings.profile = lib.mkForce [
    {
      time = "07:00";
      identity = true;
    }
    {
      time = "18:00";
      temperature = 4500;
    }
    {
      time = "19:30";
      temperature = 4000;
    }
    {
      time = "21:00";
      temperature = 3500;
    }
    {
      time = "23:00";
      temperature = 3000;
    }
  ];
}
