#!/bin/bash

# Directory setup
BG_DIR="$HOME/.config/omarchy/current/theme/backgrounds/"
CURRENT_LINK="$HOME/.config/omarchy/current/background"

# Check if chafa is installed for previews
if ! command -v chafa &> /dev/null; then
    echo "Error: 'chafa' is required for terminal image previews."
    echo "Install it with: sudo pacman -S chafa"
    exit 1
fi

# FZF Command explanation:
# 1. find: lists files
# 2. fzf: creates the menu
# 3. --preview: uses chafa to display the image of the currently highlighted file
# 4. --preview-window: places the image on top (up:60%) simulating a vertical carousel

SELECTED_WALLPAPER=$(find -L "$BG_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) | \
    sort | \
    fzf --prompt="Select Wallpaper > " \
        --height 100% \
        --layout=reverse \
        --border \
        --preview 'chafa -s 60x30 --symbols=block --stretch {}' \
        --preview-window=up:60% \
        --with-nth 1 \
        --delimiter / \
        --bind 'enter:accept')

# If the user selected an image (didn't press ESC)
if [[ -n "$SELECTED_WALLPAPER" ]]; then
    echo "Setting wallpaper: $SELECTED_WALLPAPER"
    
    # Update Symlink
    ln -nsf "$SELECTED_WALLPAPER" "$CURRENT_LINK"
    
    # Run SWWW command
    swww img -t any "$SELECTED_WALLPAPER"
    REAL_PATH=$(readlink -f "$CURRENT_BACKGROUND_LINK")
    matugen image "$REAL_PATH"
fi
