# Hyprland window groups (tabs) on t14

How to use Hyprland's tabbed window groups on t14 with the current
shortcuts. Groups are i3-style tabbed containers: several windows share
one tile and you switch between them like browser tabs.

## Quick path

**Create / dissolve a group**

1. Focus a window and press `SUPER + G` (toggles the group).
2. Add more windows: focus one, `SUPER + ALT + <arrow>` toward the group.
3. Dissolve: `SUPER + ALT + G` removes the active window from its group.

**Move a window from group A into group B**

1. `SUPER + ALT + TAB` until the tab you want is active in group A.
2. `SUPER + ALT + G` — takes it out of the group (standalone tile).
3. `SUPER + SHIFT + <arrows>` (`swapwindow`) until it sits next to group B.
4. `SUPER + ALT + <arrow toward B>` — merges it into group B.

**Reorder tabs inside the same group**

- `SUPER + CTRL SHIFT + ←/→` swaps the active tab with the
  previous/next one. Press repeatedly until it lands where you want.

## Shortcut reference

| Shortcut | Action |
|----------|--------|
| `SUPER + G` | Toggle group on active window |
| `SUPER + ALT + G` | Take active window out of its group |
| `SUPER + ALT + ←/→/↑/↓` | Merge active window into group in that direction |
| `SUPER + ALT + TAB` / `+ SHIFT` | Next / previous tab in group |
| `SUPER + CTRL + ←/→` | Previous / next tab in group |
| `SUPER + CTRL SHIFT + ←/→` | **Move** active tab backward / forward in group |
| `SUPER + ALT + 1..5` | Jump to tab 1-5 in group |
| `SUPER + ALT + scroll` | Cycle tabs |

## Notes

- `moveintogroup` is a no-op when there is no group in that direction —
  you can only merge into an existing group, never a loose window.
- All group shortcuts appear in the `SUPER + K` picker.

## Where the config lives

- The core group bindings (`SUPER G`, `SUPER ALT ...`) come from
  omarchy-nix (`modules/home-manager/hyprland/bindings.nix`).
- The tab-reordering pair (`SUPER + CTRL SHIFT + ←/→`,
  `movegroupwindow`) is a **local t14 binding** defined in
  `hosts/t14/home/hypr/groups.nix` and imported from
  `hosts/t14/home/omarchy.nix`. It is deliberately not upstreamed to
  omarchy-nix to keep the fork in sync with mrosseel/omarchy-nix.
