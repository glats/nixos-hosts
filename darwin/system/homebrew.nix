{ ... }:
{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
    };

    caskArgs.appdir = "/Applications";
    global.brewfile = true;

    brews = [
      "llmfit"
      "glow"
      "jiratui"
      "Gentleman-Programming/tap/gga"
      "age"
      "gitleaks"
      "trufflehog"
    ];
    taps = [
      "Gentleman-Programming/tap"
    ];
    casks = [
      "microsoft-edge"
      "google-chrome"
      "clipy"
      "ghostty"
      "xquartz"
      "stats"
      "caffeine"
      "meld"
      "macfuse"
      "key-codes"
      "equinox"
      "brave-browser"
      "macpacker"
      "microsoft-teams"
      "handbrake-app"
      "zoom"
      "drawio"
      "losslesscut"
      "kitty"
      "tigervnc"
      "visual-studio-code"
      "claude"
      "betterdisplay"
      "bruno"
    ];
  };
}
