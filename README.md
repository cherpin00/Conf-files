# Conf-files

Personal dotfiles: bash, tmux, vim/neovim, and a nix-darwin flake for the Mac.

Everything is installed by symlink, so the clone is the live config — edit a
file here and the change is already in effect (modulo whatever needs a reload).

```bash
git clone git@github.com:cherpin00/Conf-files.git ~/code/Conf-files
cd ~/code/Conf-files
./install.sh
```

The clone can live anywhere; nothing hard-codes the path.

## install.sh

Every step is a flag. With no arguments you get the default set for the
machine, which is detected rather than configured: on a Meta devserver the
apt-based steps are skipped, because the toolchain there is managed and
installing over it is wrong rather than merely slow.

```bash
./install.sh                      # default set for this machine
./install.sh --all                # everything
./install.sh --dotfiles --tmux    # just these
./install.sh --help               # list every step
```

| Step | Does |
|---|---|
| `--packages` | apt-install tmux, fzf, vim + Vundle, git, neovim |
| `--starship` | download the starship prompt into `~/.config/bin` |
| `--dotfiles` | symlink `vimrc`, `tmux.conf`, `tmux-theme.conf`, `tmux-scripts` into `$HOME` |
| `--bashrc-d` | symlink `bashrc.d/*` into `~/.bashrc.d` |
| `--bashrc-sourcing` | make `~/.bashrc` source `~/.bashrc.d` |
| `--vim` | run `vim +PluginInstall` |
| `--tmux` | reload the tmux config in the running server |
| `--lazyvim` | symlink `~/.config/nvim` and sync LazyVim plugins |
| `--fd` | apt-install `fd-find` (and symlink `fdfind` → `fd`) |

Steps always run in dependency order, not the order you list them: symlinks
have to exist before anything sources them, and starship has to be on disk
before `bashrc.d/starship.sh` goes looking for it.

Re-running is safe. Every step no-ops when its work is already done, and
`symlink_file` prompts before replacing anything that is a real file rather
than a symlink.

## bash

`~/.bashrc` sources `~/.bashrc.d/*`, each file a topic:

| File | Contents |
|---|---|
| `aliases.sh` | `dir`, `tp`, kubectl context shortcuts (`kt`/`kp`/`kd`), remote shells (`dev`, `becca-vm`), claude-os |
| `functions.sh` | `kdb`, `cdd`, `field`, `ip`, `test_sc_job`, plus flux/zoxide init |
| `kubectl.sh` | `copy_text_to_pod` and friends |
| `fzf.sh` | sources `~/.fzf.bash` if present |
| `starship.sh` | puts `~/.config/bin` on `PATH` and inits the prompt |

Everything that depends on an external tool is guarded by `command -v`, so
these files are safe to symlink onto a host that does not have flux, zoxide,
starship or fzf. Add a topic by dropping a new `.sh` in `bashrc.d/` and
re-running `./install.sh --bashrc-d`.

Two functions worth knowing:

```bash
kdb -c prod -n my-namespace       # throwaway netshoot debug pod
kdb -c test -h somehost           # ...pinned to a node
cdd path/to/some/file             # cd to the directory a file lives in
```

The repo's own `bashrc` is a reference copy of the sourcing snippet, not an
installed file — `install.sh` appends that snippet to your existing
`~/.bashrc` instead of replacing it.

## tmux

Prefix is `C-q`, not `C-b`, because vim wants `C-b`.

| Key | Does |
|---|---|
| <code>prefix &#124;</code> / `prefix -` | split vertically / horizontally, in the current directory |
| `M-h/j/k/l` | move between panes (no prefix) |
| `M-H/J/K/L` | resize panes (no prefix) |
| `prefix c` | new window, in the current directory |
| `prefix R` | reload config (lowercase `r` is refresh-client) |
| `prefix u` | scratchpad popup, persistent — same key dismisses it |
| `prefix e` | agent sidebar: what every running agent is doing |
| `prefix S` | fzf jump to any agent's pane |
| `prefix W` | worktree picker (`prefix w` is still `choose-tree`) |
| `v` / `y` in copy mode | begin selection / yank |

The config is split in two on purpose: `tmux.conf` is behaviour and
`tmux-theme.conf` is appearance. If the status bar ever misbehaves, comment
out the theme's `source-file` line and you are back to plain tmux with every
keybinding intact.

`tmux-scripts/` holds the `#()` scripts that feed the status bar — VCS state
(git branch, or Sapling diff number coloured by review status) and the current
kube context. Each emits its own trailing separator, or nothing at all when it
has nothing to say, so the tray collapses cleanly outside a repo.

### Iterating on tmux config

Editing `tmux.conf` in place means every mistake lands on your live sessions.
`tmux-preview` runs a **second tmux server** on its own socket with its own
config, so experiments cannot touch your real sessions:

```bash
./tmux-preview            # attach to the preview server (prefix is C-a here)
./tmux-preview reload     # re-source after an edit
./tmux-preview diff       # preview vs live
./tmux-preview promote    # install the result as your real config
```

You edit `tmux.dev.conf` / `tmux-theme.dev.conf`, which are gitignored scratch
recreated from the live config by `tmux-preview sync` (run automatically when
they are missing, as in a fresh clone). `promote` backs up the live files
first, so the `.bak.*` it leaves behind are gitignored too.

Inside the preview server the prefix is `C-a`, so it can run nested inside a
real session without the two fighting over `C-q`. Its resurrect state goes to a
scratch directory with continuum autosave off, so a throwaway preview window
can never overwrite your real saved layout.

### tmux dependencies

Not installed by `install.sh` — clone these if you want the plugin keybindings,
or delete the matching `run-shell` line from `tmux.conf`:

```bash
git clone git@github.com:cherpin00/tmux-scratchpad.git      ~/code/tmux-scratchpad
git clone git@github.com:cherpin00/tmux-agent-dashboard.git ~/code/tmux-agent-sidebar
git clone git@github.com:cherpin00/tmux-worktree.git        ~/code/tmux-worktree
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm   # then: prefix I
```

tpm manages resurrect and continuum, which save the session layout every 15
minutes and restore it on server start.

## vim / neovim

- `vimrc` — Vundle, gruvbox, NERDTree, airline, fzf. `./install.sh --vim`.
- `nvim/` — LazyVim with catppuccin, symlinked to `~/.config/nvim`.
  `./install.sh --lazyvim`. `nvim/lazy-lock.json` is gitignored, so plugin
  versions float per machine.

`alias nvimm` runs neovim under `NVIM_APPNAME=nvim-minimal`, for when a plugin
is the thing being debugged.

## Mac

`nix-darwin/` is a flake for `cherpin-mbp` — system packages, Homebrew casks
and Mac App Store apps, plus touch-id sudo and aerospace. Separate from
`install.sh`, which targets Linux:

```bash
darwin-rebuild switch --flake ./nix-darwin#cherpin-mbp
```

## Not wired up

`zshrc` and `windows_terminal_settings.json` are tracked but no install step
touches them; copy them by hand if you want them.
