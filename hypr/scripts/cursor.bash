#!/bin/bash

# get the name of current theme 
CURRENT_THEME=$(basename $(readlink ~/.config/omarchy/current/theme ))

# Apply cursor theme appropriately
case "$CURRENT_THEME" in
  "osaka-jade")
    CURSOR_THEME="Bibata-Modern-Ice"
  ;;
  
 
  *) echo default
    CURSOR_THEME="Bibata-Modern-Ice"
  ;;
esac

hyprctl setcursor $CURSOR_THEME 24
