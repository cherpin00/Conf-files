{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # home-manager for managing user dotfiles and configurations
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # nix-homebrew for managing Homebrew installations
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Optional: Declarative tap management
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, nix-homebrew, homebrew-core, homebrew-cask }:
  let
    configuration = { pkgs, config, ... }: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget

      nixpkgs.config.allowUnfree = true;

      environment.systemPackages =
        [
          pkgs.mkalias
          pkgs.neovim
          pkgs.tmux
          pkgs.iterm2
          pkgs.obsidian
          pkgs.google-chrome
          pkgs.openvpn
        ];

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Enable alternative shell support in nix-darwin.
      # programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";

      # Primary user for homebrew and other user-specific options
      system.primaryUser = "cherpin";

      # Configure Touch ID for sudo
      environment.etc."pam.d/sudo_local".text = ''
        auth       sufficient     pam_tid.so
      '';

      # System defaults
      system.defaults = {
        dock = {
          autohide = true;
          autohide-delay = 0.0;
          autohide-time-modifier = 0.2;
          show-recents = false;
          static-only = true;
          persistent-apps = [
            "/Applications/Nix Apps/iTerm2.app"
            "/Applications/Google Chrome.app"
            "/System/Applications/Finder.app"
            "/System/Applications/Launchpad.app"
          ];
        };
        finder = {
          AppleShowAllExtensions = true;
          ShowPathbar = true;
          ShowStatusBar = true;
        };
        NSGlobalDomain = {
          AppleShowAllExtensions = true;
          InitialKeyRepeat = 14;
          KeyRepeat = 1;
          AppleInterfaceStyle = "Dark";
        };
      };

      # Application activation script
      system.activationScripts.applications.text = let
        env = pkgs.buildEnv {
          name = "system-applications";
          paths = config.environment.systemPackages;
          pathsToLink = "/Applications";
        };
      in
      pkgs.lib.mkForce ''
        # Set up applications.
        echo "setting up /Applications..." >&2
        rm -rf /Applications/Nix\ Apps
        mkdir -p /Applications/Nix\ Apps
        find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
        while read -r src; do
          app_name=$(basename "$src")
          echo "copying $src" >&2
          ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
        done
      '';

      # Setup dotfiles repository
      system.activationScripts.setupDotfiles.text = ''
        echo "Setting up dotfiles repository..." >&2

        # Create ~/code directory if it doesn't exist
        mkdir -p /Users/cherpin/code

        # Clone or update Conf-files repository
        if [ ! -d "/Users/cherpin/code/Conf-files" ]; then
          echo "Cloning Conf-files repository..." >&2
          cd /Users/cherpin/code
          ${pkgs.git}/bin/git clone https://github.com/cherpin/Conf-files.git
        else
          echo "Updating Conf-files repository..." >&2
          cd /Users/cherpin/code/Conf-files
          ${pkgs.git}/bin/git pull origin main || ${pkgs.git}/bin/git pull origin master || true
        fi

        # Set proper ownership
        chown -R cherpin:staff /Users/cherpin/code/Conf-files
      '';

      # Configure Scroll Reverser preferences
      system.activationScripts.scrollReverserPrefs.text = ''
        echo "Configuring Scroll Reverser preferences..." >&2
        sudo -u cherpin defaults write com.pilotmoon.scroll-reverser ReverseScrolling -bool true
        sudo -u cherpin defaults write com.pilotmoon.scroll-reverser ReverseTrackpad -bool false
        sudo -u cherpin defaults write com.pilotmoon.scroll-reverser ReverseMouse -bool true
        sudo -u cherpin defaults write com.pilotmoon.scroll-reverser StartAtLogin -bool true
        echo "Scroll Reverser preferences configured." >&2
      '';

      # Launch agents for GUI applications
      launchd.user.agents = {
        scroll-reverser = {
          serviceConfig = {
            ProgramArguments = [ "/Applications/Scroll Reverser.app/Contents/MacOS/Scroll Reverser" ];
            RunAtLoad = true;
            KeepAlive = false;
            ProcessType = "Interactive";
          };
        };

        alt-tab = {
          serviceConfig = {
            ProgramArguments = [ "/Applications/AltTab.app/Contents/MacOS/AltTab" ];
            RunAtLoad = true;
            KeepAlive = true;
            ProcessType = "Interactive";
          };
        };
      };

      # Homebrew packages
      homebrew = {
        enable = true;
        brews = [
          "mas"
          "jq"
          "starship"
        ];
        casks = [
          "firefox"
          "alfred"
          "aerospace"
          "font-fira-code-nerd-font"
          "scroll-reverser"
          "alt-tab"
          "google-drive"
          "microsoft-remote-desktop"
        ];
        masApps = {
          "Yoink" = 408981434;
        };
        onActivation.cleanup = "zap";
        onActivation.autoUpdate = true;
        # onActivation.autoUpgrade = true;
      };
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#simple
    darwinConfigurations."cherpin-mbp" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        nix-homebrew.darwinModules.nix-homebrew
        home-manager.darwinModules.home-manager
        {
          nix-homebrew = {
            # Install Homebrew under the default prefix
            enable = true;

            # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
            enableRosetta = true;

            # User owning the Homebrew prefix
            user = "cherpin";

            # Automatically migrate existing Homebrew installations
            autoMigrate = true;

            # Optional: Declarative tap management
            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
            };

            # Optional: Enable fully-declarative tap management
            # With mutableTaps disabled, taps can no longer be added imperatively with `brew tap`.
            # Temporarily set to true for initial migration
            mutableTaps = true;
          };

          # Home Manager configuration
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.cherpin = { pkgs, ... }:
            let
              dotfilesPath = "/Users/cherpin/code/Conf-files";
            in {
              home.stateVersion = "24.05";

              # Neovim configuration
              home.file.".config/nvim" = {
                source = "${dotfilesPath}/nvim";
                recursive = true;
              };

              # Tmux configuration
              home.file.".tmux.conf".source = "${dotfilesPath}/tmux.conf";

              # Bash configuration
              home.file.".bashrc".source = "${dotfilesPath}/bashrc";
              home.file.".bashrc.d" = {
                source = "${dotfilesPath}/bashrc.d";
                recursive = true;
              };

              # Enable programs
              programs.neovim.enable = true;
              programs.tmux.enable = true;
              programs.bash.enable = true;
            };
          };
        }
      ];
    };
  };
}
