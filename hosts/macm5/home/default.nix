[
  ../../../darwin/home

  ({ lib, ... }: {
    home.opencode.activeProviderName = lib.mkForce "github-copilot-medium";
  })
]
