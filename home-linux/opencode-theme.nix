# OpenCode custom glats theme — maps the shared glats base16 palette
# to OpenCode ThemeJson tokens, replacing the dynamic "system" theme
# which generates invisible dark greys against #000000 backgrounds.
#
# Deployed to ~/.config/opencode/themes/glats.json and loaded
# automatically by OpenCode (scanned via Glob at startup).
#
# ThemeJson schema: packages/tui/src/theme/index.ts (anomalyco/opencode)
# Colors: shared/palette.nix (single source of truth across all hosts)
{ config, lib, ... }:

let
  p = config.colorScheme.palette;
  h = x: "#${x}";
in
{
  xdg.configFile."opencode/themes/glats.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/theme.json";
    theme = {
      # ── Primary / accent ─────────────────────────────────────────────
      primary = h p.base0D;
      secondary = h p.base0E;
      accent = h p.base0C;

      # ── Status ───────────────────────────────────────────────────────
      error = h p.base08;
      warning = h p.base09;
      success = h p.base0B;
      info = h p.base0C;

      # ── Text ─────────────────────────────────────────────────────────
      text = h p.base05;
      # DEBUG: bumped to near-white — if this still isn't visible
      # the theme file is not being loaded at all.
      textMuted = h p.base05;
      syntaxComment = h p.base05;

      # ── Backgrounds (dark, matching original opencode theme's subtle panels) ─
      # base01 = 10% grey — used for panels/elements/menus
      # Keep backgrounds dark; the fix is for BORDERS to be visible, not panels
      # background: match system-theme behavior — let terminal bg show through
      background = "#000000";
      backgroundPanel = h p.base01;
      backgroundElement = h p.base01;
      backgroundMenu = h p.base01;

      # ── Borders (the actual fix — these must be visible against dark bg) ─
      # borderSubtle=base02  (#505050) — visible but not glaring
      # border=base03        (#767676) — clearly visible
      # borderActive=base04  (#a0a0a0) — very visible
      borderSubtle = h p.base02;
      border = h p.base03;
      borderActive = h p.base04;

      # ── Diff ─────────────────────────────────────────────────────────
      diffAdded = h p.base0B;
      diffRemoved = h p.base08;
      diffContext = h p.base03;
      diffHunkHeader = h p.base03;
      diffHighlightAdded = h p.base0B;
      diffHighlightRemoved = h p.base08;
      diffAddedBg = h p.base01;
      diffRemovedBg = h p.base01;
      diffContextBg = h p.base01;
      diffLineNumber = h p.base05;
      diffAddedLineNumberBg = h p.base01;
      diffRemovedLineNumberBg = h p.base01;

      # ── Markdown ─────────────────────────────────────────────────────
      markdownText = h p.base05;
      markdownHeading = h p.base05;
      markdownLink = h p.base0D;
      markdownLinkText = h p.base0C;
      markdownCode = h p.base0B;
      markdownBlockQuote = h p.base0A;
      markdownEmph = h p.base0A;
      markdownStrong = h p.base09;
      markdownHorizontalRule = h p.base04;
      markdownListItem = h p.base0D;
      markdownListEnumeration = h p.base0C;
      markdownImage = h p.base0D;
      markdownImageText = h p.base0C;
      markdownCodeBlock = h p.base05;

      # ── Syntax ───────────────────────────────────────────────────────
      syntaxKeyword = h p.base0E;
      syntaxFunction = h p.base0D;
      syntaxVariable = h p.base05;
      syntaxString = h p.base0B;
      syntaxNumber = h p.base09;
      syntaxType = h p.base0A;
      syntaxOperator = h p.base0C;
      syntaxPunctuation = h p.base05;

      # ── Misc ─────────────────────────────────────────────────────────
      thinkingOpacity = 0.5;
    };
  };
}
