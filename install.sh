#!/bin/bash
set -e # Exit immediately on error

# Get the directory of the script
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# No dots in repo filenames; each is symlinked to ~/.<name>. tmux.conf refers
# to ~/.tmux-theme.conf and ~/.tmux-scripts rather than to the repo, so the
# clone can live anywhere.
DOTFILES=("vimrc" "tmux.conf" "tmux-theme.conf")
DOTDIRS=("tmux-scripts")             # Directories symlinked to ~/.<name>
BASHRC_D_DIR="$HOME/.bashrc.d"       # Location for bashrc.d scripts
NVIM_CONFIG_DIR="$HOME/.config/nvim" # Neovim config directory

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
  for dir in "${DOTDIRS[@]}"; do
    symlink_file "$DOTFILES_DIR/$dir" "$HOME/.$dir"
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

  # Ensure Neovim config directory exists in the dotfiles repo
  mkdir -p "$DOTFILES_DIR/nvim"

  # Remove existing ~/.config/nvim if it's not already a symlink
  if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
    echo "Removing existing Neovim config directory..."
    rm -rf "$HOME/.config/nvim"
  fi

  # Create a symlink from ~/.config/nvim to dotfiles/nvim
  if [ ! -L "$HOME/.config/nvim" ]; then
    ln -s "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
    echo "Symlinked: $HOME/.config/nvim → $DOTFILES_DIR/nvim"
  fi

  # Clone LazyVim starter config if it's missing in your Git repo
  if [ ! -f "$DOTFILES_DIR/nvim/init.lua" ]; then
    echo "Cloning LazyVim starter template..."
    git clone https://github.com/LazyVim/starter "$DOTFILES_DIR/nvim"

    # Remove .git folder to prevent nested Git repo issues
    rm -rf "$DOTFILES_DIR/nvim/.git"
    echo "Removed .git folder from LazyVim config to avoid nested Git issues."

    # Commit the initial LazyVim setup to the dotfiles Git repo
    cd "$DOTFILES_DIR"
    git add nvim
    git commit -m "Added LazyVim starter config"
    cd -
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

function install_starship() {
  echo "Installing Starship prompt..."

  STARSHIP_BIN="$HOME/.config/bin/starship"

  if [ -x "$STARSHIP_BIN" ]; then
    echo "Starship is already installed. Skipping installation."
    return
  fi

  mkdir -p "$HOME/.config/bin"
  curl -Lo /tmp/starship.tar.gz \
    https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz
  tar -xzf /tmp/starship.tar.gz -C "$HOME/.config/bin"
  rm -f /tmp/starship.tar.gz

  if [ ! -x "$STARSHIP_BIN" ]; then
    echo "❌ Starship installation failed." >&2
    exit 1
  fi

  echo "✅ Starship installed successfully."
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

# ---------------------------------------------------------------------------
# Step selection
# ---------------------------------------------------------------------------
# Every step is a flag. With no flags you get the default set for this machine,
# which is the point of the split: the link/configure steps are cheap and safe
# everywhere, while the apt-based installs need sudo and a Debian box, and are
# actively wrong on a Meta devserver where the toolchain is already managed.

# Ordered: symlinks have to exist before anything sources them, and starship
# has to be on disk before bashrc.d/starship.sh looks for it.
STEPS=(packages starship dotfiles bashrc_d bashrc_sourcing vim tmux lazyvim fd)

declare -A STEP_FN=(
  [packages]=install_packages
  [starship]=install_starship
  [dotfiles]=symlink_dotfiles
  [bashrc_d]=symlink_bashrc_d
  [bashrc_sourcing]=ensure_bashrc_sourcing
  [vim]=configure_vim
  [tmux]=configure_tmux
  [lazyvim]=install_lazyvim
  [fd]=install_fd
)

declare -A STEP_HELP=(
  [packages]="apt-install tmux, fzf, vim+Vundle, git, neovim"
  [starship]="download the starship prompt into ~/.config/bin"
  [dotfiles]="symlink vimrc, tmux.conf, tmux-theme.conf, tmux-scripts into \$HOME"
  [bashrc_d]="symlink bashrc.d/* into ~/.bashrc.d"
  [bashrc_sourcing]="make ~/.bashrc source ~/.bashrc.d"
  [vim]="run vim +PluginInstall"
  [tmux]="reload tmux config in the running server"
  [lazyvim]="symlink ~/.config/nvim and sync LazyVim plugins"
  [fd]="apt-install fd-find"
)

# "meta" boxes get their packages from the managed image, not from apt.
function detect_env() {
  if [ -d /usr/facebook ] || [ -e /etc/fbwhoami ]; then
    echo meta
  else
    echo generic
  fi
}

function default_steps() {
  case "$(detect_env)" in
  # starship is in the meta set too: it needs no sudo and no apt, installing a
  # single binary under $HOME, and is a no-op once that binary exists.
  meta) echo starship dotfiles bashrc_d bashrc_sourcing vim tmux ;;
  *) echo "${STEPS[@]}" ;;
  esac
}

function usage() {
  cat <<EOF
usage: install.sh [--all] [--<step>...] [--list] [--help]

With no arguments, runs the default set for this machine
(detected: $(detect_env)):
  $(default_steps)

Steps:
EOF
  for step in "${STEPS[@]}"; do
    printf '  --%-16s %s\n' "${step//_/-}" "${STEP_HELP[$step]}"
  done
}

declare -A SELECTED=()

while [ $# -gt 0 ]; do
  case "$1" in
  --all)
    for step in "${STEPS[@]}"; do SELECTED[$step]=1; done
    ;;
  --list | --help | -h)
    usage
    exit 0
    ;;
  --*)
    # Accept --bashrc-d as well as --bashrc_d.
    step="${1#--}"
    step="${step//-/_}"
    if [ -z "${STEP_FN[$step]:-}" ]; then
      echo "❌ Unknown step: $1" >&2
      echo >&2
      usage >&2
      exit 2
    fi
    SELECTED[$step]=1
    ;;
  *)
    echo "❌ Unexpected argument: $1" >&2
    exit 2
    ;;
  esac
  shift
done

if [ ${#SELECTED[@]} -eq 0 ]; then
  for step in $(default_steps); do SELECTED[$step]=1; done
fi

# Iterate STEPS, not SELECTED: associative arrays have no order, and these
# steps do have one.
for step in "${STEPS[@]}"; do
  [ -n "${SELECTED[$step]:-}" ] || continue
  "${STEP_FN[$step]}"
done

echo "✅ Setup complete! Restart your terminal to apply changes."
