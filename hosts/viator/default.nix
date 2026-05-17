{
  pkgs,
  inputs,
  ...
}: let
  user = rec {
    name = "conor";
    home = "/Users/${name}";
    uid = 501;
  };

  wallpaper = ./wallpaper.png;

  yabai = "${pkgs.yabai}/bin/yabai";
  open = "/usr/bin/open";
in {
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.determinate.darwinModules.default
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      # inputs.neovim-nightly-overlay.overlays.default
      inputs.fenix.overlays.default
      (_final: prev: {
        zjstatus = inputs.zjstatus.packages.${prev.system}.default;
      })
    ];
  };

  # Determinate owns the daemon; nix-darwin should not try to manage nix-daemon.
  nix.enable = false;

  determinateNix = {
    enable = true;

    customSettings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "build-time-fetch-tree"
        "ca-derivations"
        "git-hashing"
        "parallel-eval"
        "pipe-operators"
        "parse-toml-timestamps"
        "blake3-hashes"
        "auto-allocate-uids"
      ];

      # Single-user dev machine: allow trusted flakes/caches without repeated prompts.
      accept-flake-config = true;

      # Local build scheduling. On Apple Silicon, max-jobs=auto + cores=0 gives the
      # daemon freedom to size parallelism without hard-pinning per-derivation cores.
      max-jobs = "auto";
      cores = 0;

      # Aggressive, but still sane, substitution/download parallelism for fast switches.
      http-connections = 50;
      max-substitution-jobs = 32;
      download-buffer-size = 1024 * 1024 * 256; # 256 MiB
      nar-buffer-size = 1024 * 1024 * 128; # 128 MiB
      connect-timeout = 5;

      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://fenix.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWnlO0Vq5vUPh3FMWrMceoGbj6rQ="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "fenix.cachix.org-1:ecJhr+RdYEdcVgUkjruiYhjbBloIEGov7bos90cZi0Q="
      ];

      trusted-users = [
        "root"
        "@admin"
        user.name
      ];

      builders-use-substitutes = true;
      fallback = false;

      # Keep graph metadata for better rebuild/substitution reuse.
      keep-derivations = true;
      keep-outputs = true;

      # Guardrails for laptop storage pressure.
      min-free = 1024 * 1024 * 1024 * 10; # 10 GiB
      max-free = 1024 * 1024 * 1024 * 30; # 30 GiB

      auto-optimise-store = true;
    };
  };

  nix-homebrew = {
    enable = true;
    user = user.name;
    enableRosetta = false;
    taps = {
      "homebrew/homebrew-cask" = inputs.tap-brew-cask;
    };
    mutableTaps = false;
  };

  homebrew = {
    enable = true;
    enableFishIntegration = true;

    # Keep darwin-rebuild deterministic and fast. Upgrade casks manually when you
    # actually want to pay the network/update cost.
    global = {
      autoUpdate = false;
      brewfile = true;
    };

    onActivation = {
      cleanup = "zap";
      autoUpdate = false;
      upgrade = false;
    };

    casks = [
      "nordvpn"
      "visual-studio-code"
      # "ghostty"
    ];
  };

  environment = {
    shells = [pkgs.fish];
    variables = {
      HOMEBREW_NO_ANALYTICS = "1";
      HOMEBREW_NO_AUTO_UPDATE = "1";
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less -FRX";
    };
  };

  networking = {
    hostName = "viator";
    knownNetworkServices = ["Wi-Fi"];
    dns = [
      "1.1.1.1"
      "1.0.0.1"
    ];
    applicationFirewall = {
      enable = true;
      enableStealthMode = true;
      # blockAllIncoming=true makes signed-app allowances and local dev servers
      # mostly useless. Keep stealth mode on, but allow explicitly trusted apps.
      blockAllIncoming = false;
      allowSigned = true;
      allowSignedApp = true;
    };
  };

  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
    reattach = true;
  };

  services = {
    yabai = {
      enable = true;
      enableScriptingAddition = true;
      config = {
        layout = "bsp";
        window_placement = "second_child";
        window_shadow = "off";
        active_window_opacity = "1.0";
        normal_window_opacity = "1.0";
        window_opacity = "off";
        insert_feedback_color = "0xffff5f57";
        auto_balance = "off";
        split_ratio = "0.5";
        focus_follows_mouse = "off";
        mouse_follows_focus = "off";
        mouse_modifier = "fn";
        mouse_action1 = "move";
        mouse_action2 = "resize";
        window_animation_duration = "0.0";
        top_padding = 3;
        bottom_padding = 3;
        left_padding = 3;
        right_padding = 3;
        window_gap = 3;
      };
      extraConfig = ''
        ${yabai} -m signal --add event=dock_did_restart action="sudo ${yabai} --load-sa"
        sudo ${yabai} --load-sa

        # Some yabai builds/macOS versions require Screen Recording for this; keep
        # activation robust if Apple breaks the private animation hook again.
        ${yabai} -m config window_animation_duration 0.0 || true

        ${yabai} -m rule --add app="^System Settings$" manage=off
        ${yabai} -m rule --add app="^Calculator$" manage=off
        ${yabai} -m rule --add app="^Activity Monitor$" manage=off
        ${yabai} -m rule --add app="^BetterDisplay$" manage=off
        ${yabai} -m rule --add app="^NordVPN$" manage=off
        ${yabai} -m rule --add app="^Ghostty$" title="^Settings$" manage=off
      '';
    };

    skhd = {
      enable = true;
      skhdConfig = ''
        # Keep global shortcuts on cmd-based chords so they stay out of the way,
        # and split space vs window actions onto distinct bindings.
        ctrl + cmd - h     : ${yabai} -m space --focus prev || ${yabai} -m space --focus last
        ctrl + cmd - l     : ${yabai} -m space --focus next || ${yabai} -m space --focus first

        # Direct indexed spaces.
        ctrl + cmd - 1 : ${yabai} -m space --focus 1
        ctrl + cmd - 2 : ${yabai} -m space --focus 2
        ctrl + cmd - 3 : ${yabai} -m space --focus 3
        ctrl + cmd - 4 : ${yabai} -m space --focus 4
        ctrl + cmd - 5 : ${yabai} -m space --focus 5
        ctrl + cmd - 6 : ${yabai} -m space --focus 6
        ctrl + cmd - 7 : ${yabai} -m space --focus 7
        ctrl + cmd - 8 : ${yabai} -m space --focus 8
        ctrl + cmd - 9 : ${yabai} -m space --focus 9

        # Move focused window to indexed spaces without switching unless yabai
        # needs the fallback focus to make the transition visible.
        shift + ctrl + cmd - 1 : ${yabai} -m window --space 1
        shift + ctrl + cmd - 2 : ${yabai} -m window --space 2
        shift + ctrl + cmd - 3 : ${yabai} -m window --space 3
        shift + ctrl + cmd - 4 : ${yabai} -m window --space 4
        shift + ctrl + cmd - 5 : ${yabai} -m window --space 5
        shift + ctrl + cmd - 6 : ${yabai} -m window --space 6
        shift + ctrl + cmd - 7 : ${yabai} -m window --space 7
        shift + ctrl + cmd - 8 : ${yabai} -m window --space 8
        shift + ctrl + cmd - 9 : ${yabai} -m window --space 9

        # Tiling window focus/move/resize. Uses cmd-based chords so it does not
        # collide with your Zellij/Neovim Ctrl-hjkl path.
        alt + cmd - h : ${yabai} -m window --focus west
        alt + cmd - j : ${yabai} -m window --focus south
        alt + cmd - k : ${yabai} -m window --focus north
        alt + cmd - l : ${yabai} -m window --focus east

        shift + alt + cmd - h : ${yabai} -m window --swap west
        shift + alt + cmd - j : ${yabai} -m window --swap south
        shift + alt + cmd - k : ${yabai} -m window --swap north
        shift + alt + cmd - l : ${yabai} -m window --swap east

        ctrl + alt + cmd - h : ${yabai} -m window --warp west
        ctrl + alt + cmd - j : ${yabai} -m window --warp south
        ctrl + alt + cmd - k : ${yabai} -m window --warp north
        ctrl + alt + cmd - l : ${yabai} -m window --warp east

        ctrl + cmd - space : ${yabai} -m window --toggle float
        ctrl + cmd - f     : ${yabai} -m window --toggle zoom-fullscreen
        ctrl + cmd - b     : ${yabai} -m space --balance
        ctrl + cmd - r     : ${yabai} -m space --rotate 90
        ctrl + cmd - y     : ${yabai} -m space --mirror y-axis
        ctrl + cmd - x     : ${yabai} -m space --mirror x-axis

        ctrl + cmd - return : ${open} -na Ghostty
      '';
    };
  };

  system = {
    stateVersion = 6;
    primaryUser = user.name;

    activationScripts = {
      extraActivation.text = ''
            echo "setting desktop wallpaper..."

            uid="$(/usr/bin/id -u ${user.name})"

            /bin/launchctl asuser "$uid" /usr/bin/sudo -u ${user.name} /usr/bin/osascript <<'EOF'
              tell application "System Events"
                set picture of every desktop to POSIX file "${wallpaper}"
              end tell
        EOF
      '';
      preActivation.text = ''
        echo "Disabling Spotlight indexing..."

        /usr/bin/mdutil -a -i off || true
        /usr/bin/mdutil -a -E || true

        # # Prevent indexing on common mounted volumes.
        # for volume in / /System/Volumes/Data /Volumes/*; do
        #   if [ -d "$volume" ]; then
        #     /usr/bin/touch "$volume/.metadata_never_index" 2>/dev/null || true
        #   fi
        # done
      '';
    };

    defaults = {
      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        # Koda-ish system accent/highlight: restrained blue, not neon confetti.
        # AppleAccentColor = 4;
        # AppleHighlightColor = "0.698039 0.843137 1.000000 Blue";
        _HIHideMenuBar = true;
        AppleShowAllFiles = true;
        AppleShowAllExtensions = true;
        AppleShowScrollBars = "WhenScrolling";
        AppleSpacesSwitchOnActivate = false;
        AppleWindowTabbingMode = "manual";
        AppleEnableMouseSwipeNavigateWithScrolls = false;
        AppleEnableSwipeNavigateWithScrolls = false;
        ApplePressAndHoldEnabled = false;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticInlinePredictionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = false;
        NSDocumentSaveNewDocumentsToCloud = false;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        NSScrollAnimationEnabled = false;
        NSUseAnimatedFocusRing = false;
        NSWindowResizeTime = 0.001;
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
      };

      controlcenter = {
        BatteryShowPercentage = true;
        Bluetooth = true;
        Display = true;
        Sound = true;
      };

      dock = {
        autohide = true;
        autohide-delay = 0.0;
        autohide-time-modifier = 0.0;
        mru-spaces = false;
        launchanim = false;
        minimize-to-application = true;
        show-recents = false;
        show-process-indicators = true;
        showDesktopGestureEnabled = false;
        showLaunchpadGestureEnabled = false;
        showMissionControlGestureEnabled = true;
        expose-animation-duration = 0.0;
      };

      finder = {
        AppleShowAllExtensions = true;
        FXDefaultSearchScope = "SCcf";
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv";
        FXRemoveOldTrashItems = true;
        NewWindowTarget = "Home";
        QuitMenuItem = true;
        CreateDesktop = false;
        ShowPathbar = true;
        ShowStatusBar = true;
        _FXShowPosixPathInTitle = true;
        _FXSortFoldersFirst = true;
      };

      loginwindow = {
        GuestEnabled = false;
      };

      screencapture = {
        disable-shadow = true;
        show-thumbnail = false;
        target = "file";
        location = "${user.home}/Pictures/Screenshots";
      };

      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
        TrackpadThreeFingerDrag = true;
        TrackpadThreeFingerHorizSwipeGesture = 0;
        TrackpadThreeFingerVertSwipeGesture = 2;
        TrackpadFourFingerHorizSwipeGesture = 0;
        TrackpadFourFingerVertSwipeGesture = 0;
      };

      WindowManager = {
        EnableStandardClickToShowDesktop = false;
      };

      spaces.spans-displays = false;
      universalaccess.reduceMotion = true;

      CustomUserPreferences = {
        # Control Center / menu bar items.
        "com.apple.controlcenter" = {
          "NSStatusItem Visible Battery" = true;
          "NSStatusItem Visible WiFi" = false;
          "NSStatusItem Visible Bluetooth" = false;
          "NSStatusItem Visible Sound" = false;
          "NSStatusItem Visible NowPlaying" = false;
          "NSStatusItem Visible FocusModes" = false;
          "NSStatusItem Visible ScreenMirroring" = false;
          "NSStatusItem Visible Display" = false;
          "NSStatusItem Visible AccessibilityShortcuts" = false;
          "NSStatusItem Visible UserSwitcher" = false;
          "NSStatusItem Visible KeyboardBrightness" = false;
        };

        "com.apple.menuextra.battery" = {
          ShowPercent = true;
        };

        # Let Raycast take Cmd-Space / Option-Cmd-Space cleanly.
        "com.apple.symbolichotkeys" = {
          AppleSymbolicHotKeys = {
            "64".enabled = false;
            "65".enabled = false;
          };
        };

        "com.apple.AdLib" = {
          allowApplePersonalizedAdvertising = false;
        };

        "com.apple.desktopservices" = {
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };

        "com.apple.dock" = {
          "workspaces-edge-delay" = 0.0;
          "workspaces-swoosh-animation-off" = true;
        };

        # Hide Spotlight menu-bar icon on older/macOS-compatible setups.
        # On newer macOS this may be ignored because menu bar items moved.
        "com.apple.Spotlight" = {
          MenuItemHidden = true;
        };

        "com.apple.finder" = {
          FXInfoPanesExpanded = {
            General = true;
            OpenWith = true;
            Privileges = true;
          };
        };
      };
    };

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };
  };

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
  ];

  programs = {
    fish.enable = true;
  };

  users.users.${user.name} = {
    inherit (user) name home uid;
    shell = pkgs.fish;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
    };
    users.${user.name} = import ./home.nix;
  };
}
