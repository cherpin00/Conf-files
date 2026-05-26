if [ -x "$HOME/.config/bin/starship" ]; then
  export PATH="$HOME/.config/bin:$PATH"
  eval "$("$HOME/.config/bin/starship" init bash)"
fi
