[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

if [ -x "$HOME/.cargo/bin/starship" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
  eval "$("$HOME/.cargo/bin/starship" init bash)"
fi
