{ lib
, buildGoModule
, gentle-ai-src
}:

buildGoModule {
  pname = "gentle-ai";
  version = gentle-ai-src.rev or "unstable";

  src = gentle-ai-src;

  subPackages = [ "cmd/gentle-ai" ];

  vendorHash = "sha256-todsAjNOtV/fX4agsaqFwC0MHerMCVB0ufJk1sGSm/Y=";

  # Local override for the OpenCode skill-registry startup plugin: upstream
  # resolves the plugin cwd from `input.worktree`, which OpenCode populates
  # with "/" for git-less directories, so the refresh always skipped there.
  # The embedded asset tree ships to `gentle-ai sync`, which rewrites the
  # deployed plugin file — so the CLI embed must match the gentle-ai-assets
  # override below. TODO(upstream): drop both overrides once gentle-ai-src
  # carries the worktree-root fix (Gentleman-Programming/gentle-ai).
  postPatch = ''
    cp ${../gentle-ai-assets/skill-registry-worktree-root.ts} internal/assets/opencode/plugins/skill-registry.ts
  '';

  meta = with lib; {
    description = "AI ecosystem configurator with persistent memory and SDD workflow";
    homepage = "https://github.com/Gentleman-Programming/gentle-ai";
    license = licenses.mit;
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
    ];
    maintainers = [ ];
  };
}
