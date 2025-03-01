#!/bin/bash
set -e # Exit immediately on error

# Get the directory of the script
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES=("bashrc" "vimrc" "tmux.conf") # No dots in repo filenames
BASHRC_D_DIR="$HOME/.bashrc.d"          # Location for bashrc.d scripts
NVIM_CONFIG_DIR="$HOME/.config/nvim"    # Neovim config directory

# Check if sudo is available
if command -v sudo &>/dev/null; then
  SUDO="sudo"
else
  SUDO=""
fi

function install_neovim() {
  echo "Installing Neovim..."

  # Check if Neovim is already installed
  if command -v nvim &>/dev/null; then
    echo "Neovim is already installed. Skipping installation."
    return
  fi

  # Install Neovim using apt
  echo "Using apt to install Neovim..."
  $SUDO apt update && $SUDO apt install -y neovim

  # Verify Neovim installation
  if ! command -v nvim &>/dev/null; then
    echo "❌ Neovim installation failed." >&2
    exit 1
  fi

  echo "✅ Neovim installed successfully."
}

function install_packages() {
  echo "Installing required packages..."

  # Install tmux if not installed
  if ! command -v tmux &>/dev/null; then
    $SUDO apt install -y tmux
  fi

  # Install fzf if not installed
  if [ ! -d "$HOME/.fzf" ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  fi
  ~/.fzf/install --all

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

  install_neovim
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

function install_lazyvim() {
  echo "Installing LazyVim..."

  # Ensure Neovim config directory exists
  mkdir -p "$NVIM_CONFIG_DIR"

  # Clone LazyVim starter config if the directory is empty
  if [ ! "$(ls -A $NVIM_CONFIG_DIR)" ]; then
    echo "Cloning LazyVim starter template..."
    git clone https://github.com/LazyVim/starter "$NVIM_CONFIG_DIR"
  fi

  # Ensure all Neovim dotfiles from the repo are symlinked
  if [ -d "$DOTFILES_DIR/nvim" ]; then
    echo "Symlinking Neovim configuration..."
    for file in "$DOTFILES_DIR/nvim/"*; do
      symlink_file "$file" "$NVIM_CONFIG_DIR/$(basename "$file")"
    done
  else
    echo "No Neovim config found in dotfiles repo."
  fi

  # Install LazyVim plugins
  echo "Installing LazyVim plugins..."
  nvim --headless "+Lazy! sync" +qa
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

function install_fd() {
  echo "Installing fd..."

  # Check if fd is already installed
  if command -v fd &>/dev/null; then
    echo "fd is already installed. Skipping installation."
    return
  fi

  # Install fd using apt (package name is fd-find)
  echo "Using apt to install fd-find..."
  $SUDO apt update && $SUDO apt install -y fd-find

  # Ensure fd is available as 'fd' (Debian installs it as 'fdfind')
  if ! command -v fd &>/dev/null && command -v fdfind &>/dev/null; then
    echo "Creating 'fd' symlink for compatibility..."
    $SUDO ln -s $(which fdfind) /usr/local/bin/fd
  fi

  # Verify fd installation
  if ! command -v fd &>/dev/null; then
    echo "❌ fd installation failed." >&2
    exit 1
  fi

  echo "✅ fd installed successfully."
}

# Run installation steps
install_packages
symlink_dotfiles
symlink_bashrc_d
ensure_bashrc_sourcing
configure_vim
configure_tmux
install_lazyvim
install_fd

echo "✅ Setup complete! Restart your terminal to apply changes."
