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
  # Ensure GNU time is used (install with: pkg install time)
  local time_cmd="command time" 
  
  if [[ "$1" == "--no" ]]; then
    shift
    local f="$1"
    local bin="./${f%.cpp}"
    g++ "$f" -o "$bin" && {
      # Redirect bin stdout to tty, capture time stderr into var
      local stats=$($time_cmd -f "%e %M" "$bin" 2>&1 >/dev/tty)
      local r_time=$(echo "$stats" | awk '{print $1 * 1000}')
      local r_mem=$(echo "$stats" | awk '{print $2}')
      
      # FIX: Added variables to printf
      printf "\n\nTime: %s ms | Memory: %s KB\n" "$r_time" "$r_mem"
    }
  else
    local f="$1"
    local in="${2:-input.txt}"
    local bin="./${f%.cpp}"
    g++ "$f" -o "$bin" && {
      local stats=$($time_cmd -f "%e %M" "$bin" < "$in" 2>&1 >/dev/tty)
      local r_time=$(echo "$stats" | awk '{print $1 * 1000}')
      local r_mem=$(echo "$stats" | awk '{print $2}')
      printf "\n\nTime: %s ms | Memory: %s KB\n" "$r_time" "$r_mem"
    }
  fi
}

rncpp() {
  rcpp --no "$@"
}

unalias ff 2>/dev/null

ff() {
  fzf \
    --preview '[[ -f {} ]] && bat --style=numbers --color=always --paging=never --line-range :300 {}' \
    --preview-window=up:70% \
    --bind 'ctrl-d:execute(
        read -p "Delete {}? (y/n): " confirm && 
        [[ $confirm == [yY] ]] && rm -v {} && 
        || echo "Aborted"
    )' \
    --bind 'ctrl-e:execute(
        $EDITOR {}
    )' \
    --bind 'enter:execute(
        $EDITOR {}
    )+accept' \
    "$@"
}

unalias ffr 2>/dev/null

ffr() {
  rg --line-number --no-heading --color=always "" |
  fzf --ansi \
      --preview 'bat --color=always --paging=never {1} --highlight-line {2}' \
      --preview-window=up:60% \
      --delimiter ':' \
      --bind 'change:reload:rg --line-number --no-heading --color=always {q} || true'
}

# pyenv setup
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
