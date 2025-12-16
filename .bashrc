# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
#source ~/.config/self_scripts/checkvenv
source ~/.local/share/omarchy/default/bash/rc

# Custom bashrc venv prompt

prompt_venv() {
    if [ -n "$VIRTUAL_ENV" ]; then
      echo "($(basename "$VIRTUAL_ENV")) "
    fi
  }

#PROMPT_COMMAND='PS1="$(prompt_venv)$PS1 "'
# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

export NVM_DIR="$HOME/.config/nvm"
# The corrected lines below
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

source /home/archy/.config/broot/launcher/bash/br

# custom functions for some commands

unalias lt 2>/dev/null
lt() {
  local level=2
  if [[ "$1" =~ ^-[0-9]+$ ]]; then
    level=${1#-}
    shift
  fi

  eza --tree --level="${level}" --long --icons --git "$@"
}

unalias lta 2>/dev/null
lta() {
  local level=2 #default level
  if [[ "$1" =~ ^-[0-9]+$ ]]; then
    level="${1#-}"
    shift
  fi
  lt "-${level}" -a "$@"
}

rcpp() {
  f="$1"
  in="${2:-input.txt}"
  g++ "$f" -o "${f%.cpp}" && ./"${f%.cpp}" < "$in"
}
