# Tasks: uniform-look-qt-gtk-adwaita-dark

## Review Workload Forecast

| Metric | Value |
|--------|-------|
| Files changed | 1 (`hosts/t14/home/omarchy.nix`) |
| Estimated added lines | ~14 (2 comment blocks + gtk.theme + qt block) |
| Estimated deleted lines | 0 |
| Total changed lines | ~14 |
| 400-line budget risk | **Low** |
| Chained PRs recommended | No |
| Decision needed before apply | No |

---

## Phase 1: Implementation

### T-001: Add gtk.theme override and qt block in omarchy.nix

**File**: `hosts/t14/home/omarchy.nix`
**Specs covered**: R-GTK-T14-1, R-QT-T14-1
**Estimated effort**: Small (single insert, ~14 lines)

**What to do**:

Insert the following block after line 200 (`gtk.gtk4.extraConfig."gtk-interface-color-scheme" = "dark";`) and its trailing blank line, BEFORE the `thinkfan-ui` comment block (line 202). This keeps all `gtk.*` overrides grouped together and places `qt` adjacent to GTK config, matching `home-linux/theme.nix` structure.

Insert this Nix expression:

```nix
  # Override omarchy-nix's default GTK theme (Adwaita-dark) to Materia-dark-compact
  # to match rog and thinkcentre. lib.mkForce defeats omarchy's priority-100
  # definition. materia-theme is auto-installed by HM via gtk.theme.package.
  gtk.theme = lib.mkForce {
    name = "Materia-dark-compact";
    package = pkgs.materia-theme;
  };

  # Qt configuration: Adwaita Dark style with GTK3 platform theme bridge.
  # Matches home-linux/theme.nix used on rog and thinkcentre.
  # adwaita-qt is auto-installed by HM when qt.style.name = "adwaita-dark".
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style.name = "adwaita-dark";
  };
```

**Checklist**:

- [ ] `gtk.theme` uses `lib.mkForce` (required to defeat omarchy-nix's priority-100 definition)
- [ ] `gtk.theme.name` is `"Materia-dark-compact"`
- [ ] `gtk.theme.package` is `pkgs.materia-theme`
- [ ] `qt.enable` is `true`
- [ ] `qt.platformTheme.name` is `"gtk3"`
- [ ] `qt.style.name` is `"adwaita-dark"`
- [ ] Block is placed after `gtk.gtk4.extraConfig` and before `thinkfan-ui` section
- [ ] No `mkForce` on `qt.*` (omarchy-nix does not set Qt options, so no conflict)

---

## Phase 2: Verification

### T-002: Format, flake check, and commit

**Specs covered**: R-VERIFY-1
**Estimated effort**: Small (3 commands + git commit)

**What to do**:

1. Run `format-nix` to format the repository
2. Run `nix flake check --no-build` to validate all hosts
3. Verify the diff is exactly what was intended: `git diff hosts/t14/home/omarchy.nix`
4. Stage and commit with conventional commit message:
   ```
   feat(t14): add GTK Materia-dark-compact and Qt Adwaita Dark theme config
   ```

**Checklist**:

- [ ] `format-nix` passes (exit 0)
- [ ] `nix flake check --no-build` passes (exit 0, all hosts)
- [ ] `git diff` shows only the intended gtk.theme and qt additions in omarchy.nix
- [ ] No other files modified
- [ ] Commit created with conventional format

---

## Task Dependency Graph

```
T-001 (implement) ──→ T-002 (verify + commit)
```

## Summary

| Task | Phase | Scope | Effort |
|------|-------|-------|--------|
| T-001 | Implementation | Add gtk.theme + qt block to omarchy.nix | Small |
| T-002 | Verification | Format, flake check, commit | Small |
| **Total** | | **1 file, ~14 lines added** | **Small** |
