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

  if [ -L "$dst" ] && [ "$(readlink "$dst")" != "$src" ]; then
    echo "Removing incorrect symlink: $dst"
    rm -f "$dst"
  fi

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    while true; do
      read -p "$dst already exists. Overwrite? [y] yes (default), [s] skip, [c] cancel: " ysc
      case $ysc in
      [Yy]*)
        rm -rf "$dst"
        break
        ;;
      [Ss]*) return 0 ;; # Skip and continue
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

  for script in "$DOTFILES_DIR/bashrc.d/"*; do
    symlink_file "$script" "$BASHRC_D_DIR/$(basename "$script")"
  done
}

function ensure_bashrc_sourcing() {
  if ! grep -q "bashrc.d" "$HOME/.bashrc"; then
    echo "Adding ~/.bashrc.d sourcing to ~/.bashrc..."
    cat <<EOF >>"$HOME/.bashrc"

# Load additional configuration scripts from ~/.bashrc.d/
if [ -d "$HOME/.bashrc.d" ]; then
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
  tmux source-file "$HOME/.tmux.conf"
}

# Run installation steps
install_packages
symlink_dotfiles
symlink_bashrc_d
ensure_bashrc_sourcing
configure_vim
configure_tmux

echo "✅ Setup complete! Restart your terminal to apply changes."
