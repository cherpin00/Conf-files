#!/bin/bash
set -e # Exit immediately on error

DOTFILES_DIR="$HOME/.dotfiles"
DOTFILES=("bashrc" "vimrc" "tmux.conf") # No dots in repo filenames

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

function symlink_dotfiles() {
  echo "Symlinking dotfiles..."
  for file in "${DOTFILES[@]}"; do
    src="$DOTFILES_DIR/$file" # No dot in repo
    dst="$HOME/.$file"        # Symlink with dot in home directory

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
        [Ss]*) continue ;;
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
  done
}

function configure_bash() {
  echo "Configuring Bash..."
  mkdir -p "$HOME/.bashrc.d"

  if ! grep -q "User specific aliases and functions" "$HOME/.bashrc"; then
    cat <<EOF >>"$HOME/.bashrc"

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        [ -f "\$rc" ] && source "\$rc"
    done
fi
EOF
  fi

  for rc in "$HOME/.bashrc.d/"*; do
    [ -f "$rc" ] && source "$rc"
  done
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
configure_bash
configure_vim
configure_tmux

echo "✅ Setup complete! Restart your terminal."
