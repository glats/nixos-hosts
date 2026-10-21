{ ... }:
{
  launchd.agents.flameshot = {
    enable = true;
    config = {
      ProgramArguments = [
        "/Applications/flameshot.app/Contents/MacOS/flameshot"
      ];
      RunAtLoad = true;
      KeepAlive.SuccessfulExit = false;
      ThrottleInterval = 30;
      ProcessType = "Interactive";
    };
  };
}
