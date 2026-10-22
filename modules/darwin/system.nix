{
  config,
  lib,
  pkgs,
  ...
}: let
  username = config.system.primaryUser;
  home = config.users.users.${username}.home;
  appDirectory = config.home-manager.users.${username}.targets.darwin.copyApps.directory;
in {
  programs.fish.enable = true;
  environment.shells = [pkgs.fish];

  fonts.packages = [pkgs.nerd-fonts.fira-code];

  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
    reattach = true; # Touch ID inside tmux
  };

  networking = {
    knownNetworkServices = ["Wi-Fi"];
    dns = ["1.1.1.1" "1.0.0.1"];
    applicationFirewall = {
      enable = true;
      enableStealthMode = true;
      allowSigned = true;
      allowSignedApp = true;
    };
  };

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  home-manager.users.${username} = {
    # hidutil mappings are lost at reboot; nix-darwin only sets them on activation.
    launchd.agents.keyboard-remapping = {
      enable = true;
      config = {
        ProgramArguments = [
          "/usr/bin/hidutil"
          "property"
          "--set"
          (builtins.toJSON {UserKeyMapping = config.system.keyboard.userKeyMapping;})
        ];
        RunAtLoad = true;
      };
    };

    # nix-darwin's boolean FocusModes option cannot express "Show When Active".
    targets.darwin.currentHostDefaults."com.apple.controlcenter" = {
      FocusModes = 2;
      Sound = config.system.defaults.controlcenter.Sound;
    };
  };

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      _HIHideMenuBar = true;
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      AppleShowScrollBars = "WhenScrolling";
      AppleSpacesSwitchOnActivate = false;
      AppleWindowTabbingMode = "manual";
      AppleEnableSwipeNavigateWithScrolls = true;
      AppleEnableMouseSwipeNavigateWithScrolls = false;
      ApplePressAndHoldEnabled = false;
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
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
      # Ctrl-Cmd-drag moves a window from anywhere inside it.
      NSWindowShouldDragOnGesture = true;
    };

    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.0;
      expose-animation-duration = 0.0;
      launchanim = false;
      minimize-to-application = true;
      mru-spaces = false;
      show-process-indicators = true;
      show-recents = false;
      showDesktopGestureEnabled = false;
      showLaunchpadGestureEnabled = false;
      showMissionControlGestureEnabled = true;
      persistent-apps = let
        hm = app: "${home}/${appDirectory}/${app}.app";
      in [
        "/Applications/Safari.app"
        "/Applications/Brave Browser.app"
        "/System/Applications/Messages.app"
        "/System/Applications/Mail.app"
        (hm "Spotify")
        (hm "Ghostty")
        "/Applications/NordVPN.app"
        "/System/Applications/System Settings.app"
        "/Applications/Claude.app"
        "/Applications/ChatGPT.app"
        "/Applications/Muse.app"
      ];
    };

    finder = {
      AppleShowAllExtensions = true;
      CreateDesktop = false;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv";
      FXRemoveOldTrashItems = true;
      NewWindowTarget = "Home";
      QuitMenuItem = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXShowPosixPathInTitle = true;
      _FXSortFoldersFirst = true;
    };

    # Sound stays visible; Focus appears only while active.
    controlcenter = {
      BatteryShowPercentage = true;
      AirDrop = false;
      Bluetooth = false;
      Display = false;
      FocusModes = null;
      NowPlaying = false;
      Sound = true;
    };

    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = false;
      TrackpadThreeFingerHorizSwipeGesture = 2;
      TrackpadThreeFingerVertSwipeGesture = 2;
      # macOS enables both horizontal keys for three-finger desktop switching.
      TrackpadFourFingerHorizSwipeGesture = 2;
      TrackpadFourFingerVertSwipeGesture = 0;
    };

    screencapture = {
      location = "${home}/Pictures/Screenshots";
      disable-shadow = true;
      show-thumbnail = false;
      target = "file";
    };

    loginwindow.GuestEnabled = false;
    spaces.spans-displays = false;
    universalaccess.reduceMotion = false;
    WindowManager.EnableStandardClickToShowDesktop = false;

    CustomUserPreferences = {
      # Cmd-Space belongs to Raycast.
      "com.apple.symbolichotkeys".AppleSymbolicHotKeys = {
        # Cmd-Shift-4 copies a selection; add Control to save it as a file.
        "30" = {
          enabled = true;
          value = {
            parameters = [52 21 1441792];
            type = "standard";
          };
        };
        "31" = {
          enabled = true;
          value = {
            parameters = [52 21 1179648];
            type = "standard";
          };
        };
        "64".enabled = false;
        "65".enabled = false;
      };
      "com.apple.AdLib".allowApplePersonalizedAdvertising = false;
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      "com.apple.dock" = {
        workspaces-edge-delay = 0.0;
        workspaces-swoosh-animation-off = true;
      };
    };
  };

  system.activationScripts.postActivation.text = ''
    install -d -o ${lib.escapeShellArg username} -g staff ${lib.escapeShellArg "${home}/Pictures/Screenshots"}
    # Raycast and Spotlight find apps through the metadata index.
    for vol in / /System/Volumes/Data; do
      if ! /usr/bin/mdutil -s "$vol" | grep -q 'Indexing enabled'; then
        /usr/bin/mdutil -i on "$vol" >/dev/null
      fi
    done
  '';
}
