{ ... }:
{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      # "uninstall" removes the app but keeps ~/Library user data (bookmarks,
      # passwords, profiles). "zap" also deletes user data — never use for browsers.
      cleanup = "uninstall";
    };

    # no_quarantine removed in Homebrew post-5.1.10 (flag is now disabled);
    # quarantine removal handled by unquarantineTrustedApps in settings.nix
    caskArgs.appdir = "/Applications";
    global.brewfile = true;

    # homebrew is best for GUI apps
    # nixpkgs is best for CLI tools
    # gentle-ai, engram: managed by nix flake (pkgs/gentle-ai, pkgs/engram)
    brews = [
      "leaf-md"
      "tw93/tap/mole"
      "llmfit"
      "glow"
      "jiratui"
      "Gentleman-Programming/tap/gga"
      "age"
      "gitleaks"
      "trufflehog"
    ];
    taps = [
      "tw93/tap"
      "Gentleman-Programming/tap"
    ];
    casks = [
      "microsoft-edge"
      "google-chrome"
      "clipy"
      "ghostty"
      "xquartz"
      "stats"
      "postman"
      "caffeine"
      "flameshot"
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
    ];
  };
}
