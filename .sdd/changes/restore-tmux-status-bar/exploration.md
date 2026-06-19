# Exploration: Restore Omarchy Tmux Status Bar Features

## Current State

**Omarchy-nix tmux status bar** (`/tmp/omarchy-nix/config/tmux/tmux.conf` lines 74-94):
- **Status position**: top (we use bottom — user wants to keep bottom)
- **Status interval**: 5 seconds
- **Status left/right length**: 30/50
- **Window separator**: empty string (no gaps)
- **Automatic rename**: on, format `#{b:pane_current_path}`
- **Status left**: `#[fg=black,bg=blue,bold] #S #[bg=default] ` — colored session name block
- **Status right**: `#[fg=blue]#{?pane_in_mode,COPY ,}#{?client_prefix,PREFIX ,}#{?window_zoomed_flag,ZOOM ,}#[fg=brightblack]#h ` — **mode indicators + hostname**
- **Window format**: `#[fg=brightblack] #I:#W ` — index:name
- **Window current format**: `#[fg=blue,bold] #I:#W ` — highlighted current
- **Mode style**: `bg=blue,fg=black`

**Current shared/tmux.nix** (lines 29-39):
- Status position: bottom
- Base16 theme applied
- **Missing**: status-left, status-right, window-status-format, window-status-separator, automatic-rename, status-interval, message-command-style

## Affected Areas

- `shared/tmux.nix` — add status bar content and layout options
- `home-linux/tmux.nix` — no changes needed (uses shared via import)
- `home-darwin/tmux.nix` — no changes needed (uses shared via import)
- `hosts/t14/home/omarchy.nix` — no changes needed (home-linux/tmux.nix already overrides omarchy's tmux)

## Approaches

### Approach 1: Add to shared/tmux.nix (Recommended)

Add all status bar features to `shared/tmux.nix` using base16 colors.

**Pros**:
- Single source of truth (matches project philosophy)
- All hosts get it automatically (rog, thinkcentre, t14, darwin)
- Uses base16 colors (theme-aware)
- No mkForce needed

**Cons**:
- None identified

**Effort**: Low (15-20 lines of config)

**Color mapping** (omarchy → base16):
- `blue` → `base0D` (blue)
- `black` → `base00` (dark background)
- `brightblack` → `base03` (comments/dim)
- `default` → `base01` (background)

**Proposed config additions** (to insert after line 29 in shared/tmux.nix):

```nix
# Status bar layout
set -g status-interval 5
set -g status-left-length 30
set -g status-right-length 50
set -g window-status-separator ""

# Automatic window rename
setw -g automatic-rename on
setw -g automatic-rename-format '#{b:pane_current_path}'

# Status bar content
set -g status-left "#[fg=#${config.colorScheme.palette.base00},bg=#${config.colorScheme.palette.base0D},bold] #S #[bg=default] "
set -g status-right "#[fg=#${config.colorScheme.palette.base0D}]#{?pane_in_mode,COPY ,}#{?client_prefix,PREFIX ,}#{?window_zoomed_flag,ZOOM ,}#[fg=#${config.colorScheme.palette.base03}]#h "

# Window status format
setw -g window-status-format "#[fg=#${config.colorScheme.palette.base03}] #I:#W "
setw -g window-status-current-format "#[fg=#${config.colorScheme.palette.base0D},bold] #I:#W "

# Message command style
set -g message-command-style "bg=#${config.colorScheme.palette.base02},fg=#${config.colorScheme.palette.base0D}"
```

### Approach 2: Keep omarchy-nix tmux module active

Don't override omarchy's tmux on t14, let it provide the status bar.

**Pros**:
- Less code to maintain

**Cons**:
- Breaks unified single-source approach
- Only t14 gets the status bar (rog/thinkcentre don't import omarchy)
- Uses hardcoded colors (not base16)
- Conflicts with shared/tmux.nix theme

**Effort**: Low

**Verdict**: Rejected — violates project architecture

### Approach 3: Create separate status-bar module

Extract status bar into a new shared module (e.g., `shared/tmux-status.nix`).

**Pros**:
- Modular

**Cons**:
- Over-engineering for 15 lines
- Adds complexity without benefit
- Status bar is tightly coupled to tmux config

**Effort**: Medium

**Verdict**: Rejected — unnecessary abstraction

## Recommendation

**Approach 1**: Add status bar features directly to `shared/tmux.nix`.

**Why**:
1. Matches project philosophy (single source of truth)
2. All hosts get it automatically
3. Uses base16 colors (theme-aware)
4. Minimal code change (15-20 lines)
5. No breaking changes to existing config

**What the user gets back**:
- ✅ **Prefix indicator**: Shows "PREFIX " when prefix key is pressed
- ✅ **Copy mode indicator**: Shows "COPY " when in copy/selection mode
- ✅ **Zoom indicator**: Shows "ZOOM " when pane is zoomed
- ✅ **Session name**: Colored block with session name on left
- ✅ **Window format**: Shows index:name (#I:#W)
- ✅ **Hostname**: Shows hostname on far right
- ✅ **Status bar at bottom**: Keeps current position (user preference)

## Risks

1. **None identified** — purely additive config, no breaking changes
2. Prefix indicator works with any prefix key (C-b default, or C-Space if user changes it)
3. Base16 colors ensure theme consistency across all hosts

## Ready for Proposal

**Yes** — orchestrator can proceed to proposal phase.

**What to tell user**:
"We found what's missing from your tmux status bar: the mode indicators (COPY, PREFIX, ZOOM), session name block, window index:name format, and hostname. We'll add these to `shared/tmux.nix` using base16 colors so all hosts get them and they stay theme-aware. Status bar stays at the bottom as you prefer."
