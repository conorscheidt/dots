{
  config,
  lib,
  pkgs,
  ...
}:
let
  username = config.system.primaryUser;
  home = config.users.users.${username}.home;
  appDirectory = config.home-manager.users.${username}.targets.darwin.copyApps.directory;
  hm = app: "${home}/${appDirectory}/${app}.app";
in
{
  programs.fish = {
    enable = true;
    useBabelfish = true;
  };
  environment.shells = [ pkgs.fish ];
  fonts.packages = [ pkgs.nerd-fonts.fira-code ];

  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
    reattach = true;
  };

  networking = {
    knownNetworkServices = [ "Wi-Fi" ];
    dns = [
      "1.1.1.1"
      "1.0.0.1"
    ];
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

  # nix-darwin applies hidutil only during activation; reapply after login.
  launchd.user.agents.keyboard-remapping.serviceConfig = {
    ProgramArguments = [
      "/usr/bin/hidutil"
      "property"
      "--set"
      (builtins.toJSON { UserKeyMapping = config.system.keyboard.userKeyMapping; })
    ];
    RunAtLoad = true;
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
      AppleKeyboardUIMode = 2;
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
      NSWindowShouldDragOnGesture = true;
    };

    # The default, set explicitly: nix-darwin never deletes a key it stops managing.
    LaunchServices.LSQuarantine = true;

    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.0;
      expose-animation-duration = 0.0;
      expose-group-apps = true;
      launchanim = false;
      minimize-to-application = true;
      mru-spaces = true;
      show-process-indicators = true;
      show-recents = false;
      showDesktopGestureEnabled = false;
      showLaunchpadGestureEnabled = false;
      showMissionControlGestureEnabled = true;
      wvous-br-corner = 1;
      persistent-apps = [
        "/Applications/Brave Browser.app"
        "/System/Applications/Messages.app"
        "/System/Applications/Mail.app"
        "/Applications/Slack.app"
        (hm "Spotify")
        (hm "Ghostty")
        (hm "Mixxx")
        "/Applications/T3 Code (Nightly).app"
        "/Applications/ChatGPT.app"
      ];
      persistent-others = [
        {
          folder = {
            path = "${home}/Downloads";
            arrangement = "date-added";
            displayas = "stack";
            showas = "fan";
          };
        }
      ];
    };

    finder = {
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

    trackpad = {
      Clicking = true;
      FirstClickThreshold = 0;
      SecondClickThreshold = 0;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = false;
      TrackpadThreeFingerHorizSwipeGesture = 2;
      TrackpadThreeFingerVertSwipeGesture = 2;
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

    WindowManager = {
      EnableStandardClickToShowDesktop = false;
      EnableTiledWindowMargins = false;
    };

    CustomUserPreferences = {
      # The whole dict is replaced on switch: Nix owns every symbolic hotkey,
      # and omitted ones fall back to Apple's defaults.
      "com.apple.symbolichotkeys".AppleSymbolicHotKeys = {
        # Swap Cmd+Shift+4 (copy to clipboard) and Cmd+Ctrl+Shift+4 (save to file)
        "30" = {
          enabled = true;
          value = {
            parameters = [
              52
              21
              1441792
            ];
            type = "standard";
          };
        };
        "31" = {
          enabled = true;
          value = {
            parameters = [
              52
              21
              1179648
            ];
            type = "standard";
          };
        };
      };

      "com.apple.controlcenter" = {
        "NSStatusItem Preferred Position BentoBox-0" = 255;
        "NSStatusItem Preferred Position Sound" = 306;
        "NSStatusItem Preferred Position WiFi" = 329;
        "NSStatusItem Visible AccessibilityShortcuts" = false;
        "NSStatusItem Visible KeyboardBrightness" = false;
        "NSStatusItem Visible UserSwitcher" = false;
        "NSStatusItem VisibleCC Battery" = true;
        "NSStatusItem VisibleCC BentoBox-0" = true;
        "NSStatusItem VisibleCC Clock" = true;
        "NSStatusItem VisibleCC Sound" = true;
        "NSStatusItem VisibleCC WiFi" = true;
      };

      "com.apple.Spotlight".orderedItems = [
        {
          enabled = true;
          name = "APPLICATIONS";
        }
        {
          enabled = true;
          name = "SYSTEM_PREFS";
        }
        {
          enabled = true;
          name = "MENU_EXPRESSION";
        }
        {
          enabled = true;
          name = "MENU_CONVERSION";
        }
        {
          enabled = true;
          name = "DIRECTORIES";
        }
        {
          enabled = true;
          name = "PDF";
        }
        {
          enabled = false;
          name = "DOCUMENTS";
        }
        {
          enabled = false;
          name = "MESSAGES";
        }
        {
          enabled = false;
          name = "CONTACT";
        }
        {
          enabled = false;
          name = "EVENT_TODO";
        }
        {
          enabled = false;
          name = "IMAGES";
        }
        {
          enabled = false;
          name = "BOOKMARKS";
        }
        {
          enabled = false;
          name = "MUSIC";
        }
        {
          enabled = false;
          name = "MOVIES";
        }
        {
          enabled = false;
          name = "FONTS";
        }
        {
          enabled = false;
          name = "PRESENTATIONS";
        }
        {
          enabled = false;
          name = "SPREADSHEETS";
        }
        {
          enabled = false;
          name = "SOURCE";
        }
        {
          enabled = false;
          name = "MENU_DEFINITION";
        }
        {
          enabled = false;
          name = "MENU_OTHER";
        }
        {
          enabled = false;
          name = "MENU_SPOTLIGHT_SUGGESTIONS";
        }
      ];

      "com.apple.AdLib".allowApplePersonalizedAdvertising = false;
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      "com.apple.dock".workspaces-edge-delay = 0.0;
    };
  };

  system.activationScripts.postActivation.text = ''
    # Apply symbolic hotkeys to the running session (nix-darwin only writes the plist).
    launchctl asuser "$(id -u -- ${lib.escapeShellArg username})" sudo --user=${lib.escapeShellArg username} -- \
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true

    install -d -o ${lib.escapeShellArg username} -g staff ${lib.escapeShellArg "${home}/Pictures/Screenshots"}

    # Never index the /nix store volume
    if [ -d /nix ]; then
      touch /nix/.metadata_never_index 2>/dev/null || true
      /usr/bin/mdutil -i off /nix >/dev/null 2>&1 || true
    fi

    for vol in / /System/Volumes/Data; do
      if ! /usr/bin/mdutil -s "$vol" | grep -q 'Indexing enabled'; then
        /usr/bin/mdutil -i on "$vol" >/dev/null 2>&1 || true
      fi
    done
  '';
}
