# Glats theme — wallpapers
#
# Backgrounds live in this directory and are picked by omarchy's
# `omarchy-theme-bg-next` walker. The actual image files are not
# tracked in git; this README documents the deployment contract.
#
# Expected files (deployed by `omarchy-theme-set glats`):
#   - 01-glats-01.png ... 14-glats-14.png  (14 wallpaper images)
#
# The omarchy runtime cycles through this directory using
# `omarchy-theme-bg-next` (SUPER+CTRL+SPACE) and stores the current
# selection as a symlink under ~/.config/omarchy/current/background.
#
# To populate this directory on the live system:
#   1. Copy the 14 wallpaper images into ~/.config/omarchy/themes/glats/backgrounds/
#   2. Run `omarchy-theme-set glats` to activate.
