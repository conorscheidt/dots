{pkgs, ...}: {
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

    # Menu bar: battery percentage only.
    controlcenter = {
      BatteryShowPercentage = true;
      AirDrop = false;
      Bluetooth = false;
      Display = false;
      FocusModes = false;
      NowPlaying = false;
      Sound = false;
    };

    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = false;
      TrackpadThreeFingerHorizSwipeGesture = 0;
      TrackpadThreeFingerVertSwipeGesture = 2;
      TrackpadFourFingerHorizSwipeGesture = 0;
      TrackpadFourFingerVertSwipeGesture = 0;
    };

    screencapture = {
      location = "/Users/conor/Pictures/Screenshots";
      disable-shadow = true;
      show-thumbnail = false;
      target = "file";
    };

    loginwindow.GuestEnabled = false;
    spaces.spans-displays = false;
    universalaccess.reduceMotion = true;
    WindowManager.EnableStandardClickToShowDesktop = false;

    CustomUserPreferences = {
      # Cmd-Space belongs to Raycast.
      "com.apple.symbolichotkeys".AppleSymbolicHotKeys = {
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
    install -d -o conor -g staff /Users/conor/Pictures/Screenshots
    # Raycast and Spotlight find apps through the metadata index.
    if ! /usr/bin/mdutil -s / | grep -q 'Indexing enabled'; then
      /usr/bin/mdutil -i on / >/dev/null
    fi
  '';
}
