#!/bin/bash
set -e # Exit immediately on error

# Get the directory of the script
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES=("bashrc" "vimrc" "tmux.conf") # No dots in repo filenames
BASHRC_D_DIR="$HOME/.bashrc.d"          # Location for bashrc.d scripts

# Check if sudo is available
if command -v sudo &>/dev/null; then
  SUDO="sudo"
else
  SUDO=""
fi

function install_packages() {
  echo "Installing required packages..."

  # Install tmux if not installed
  if ! command -v tmux &>/dev/null; then
    $SUDO apt install -y tmux
  fi

  # Install fzf if not installed
  if [ ! -d "$HOME/.fzf" ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --all
  fi

  # Install Vim and Vundle if not installed
  if ! command -v vim &>/dev/null; then
    $SUDO apt install -y vim
  fi
  if [ ! -d "$HOME/.vim/bundle/Vundle.vim" ]; then
    git clone --depth 1 https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
  fi

  # Install git if not installed
  if ! command -v git &>/dev/null; then
    $SUDO apt install -y git
  fi
}

function symlink_file() {
  src=$1
  dst=$2

  # If the destination is a correct symlink, do nothing
  if [ -L "$dst" ] && [ "$(readlink "$dst")" == "$src" ]; then
    echo "Symlink already exists: $dst → $src (skipping)"
    return 0
  fi

  # If the destination is an incorrect symlink, remove it
  if [ -L "$dst" ] && [ "$(readlink "$dst")" != "$src" ]; then
    echo "Removing incorrect symlink: $dst"
    rm -f "$dst"
  fi

  # If the destination is a regular file or directory, prompt for overwrite
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "$dst already exists and is not a symlink."
    while true; do
      read -p "Do you want to overwrite it? [y] yes (default), [s] skip, [c] cancel: " ysc
      case $ysc in
      [Yy]*)
        rm -rf "$dst"
        break
        ;;
      [Ss]*)
        echo "Skipping $dst"
        return 0
        ;; # Skip and continue
      [Cc]*)
        echo "Install cancelled."
        exit 1
        ;;
      *)
        rm -rf "$dst"
        break
        ;;
      esac
    done
  fi

  ln -s "$src" "$dst"
  echo "Symlinked: $dst → $src"
}

function symlink_dotfiles() {
  echo "Symlinking dotfiles..."
  for file in "${DOTFILES[@]}"; do
    symlink_file "$DOTFILES_DIR/$file" "$HOME/.$file"
  done
}

function symlink_bashrc_d() {
  echo "Symlinking bashrc.d scripts..."
  mkdir -p "$BASHRC_D_DIR"

  # Ensure there are actual files before looping to avoid unwanted "*"
  if compgen -G "$DOTFILES_DIR/bashrc.d/*" >/dev/null; then
    for script in "$DOTFILES_DIR/bashrc.d/"*; do
      if [ -f "$script" ]; then
        symlink_file "$script" "$BASHRC_D_DIR/$(basename "$script")"
      fi
    done
  else
    echo "No bashrc.d scripts found."
  fi
}

function ensure_bashrc_sourcing() {
  if ! grep -q "bashrc.d" "$HOME/.bashrc"; then
    echo "Adding ~/.bashrc.d sourcing to ~/.bashrc..."
    cat <<EOF >>"$HOME/.bashrc"

# Load additional configuration scripts from ~/.bashrc.d/
if [ -d "\$HOME/.bashrc.d" ]; then
    for rc in "\$HOME/.bashrc.d/"*; do
        [ -f "\$rc" ] && source "\$rc"
    done
fi
EOF
  fi
}

function configure_vim() {
  echo "Configuring Vim..."
  vim +PluginInstall +qall
}

function configure_tmux() {
  echo "Configuring tmux..."

  # Ensure tmux is installed
  if ! command -v tmux &>/dev/null; then
    echo "tmux is not installed, skipping configuration."
    return
  fi

  # Check if a tmux server is running before sourcing the config
  if tmux info &>/dev/null; then
    echo "Reloading tmux configuration..."
    tmux source-file "$HOME/.tmux.conf"
  else
    echo "No running tmux session found. Starting a new session..."
    tmux new-session -d
    tmux source-file "$HOME/.tmux.conf"
  fi
}

# Run installation steps
install_packages
symlink_dotfiles
symlink_bashrc_d
ensure_bashrc_sourcing
configure_vim
configure_tmux

echo "✅ Setup complete! Restart your terminal to apply changes."
