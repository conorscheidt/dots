{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  ns = pkgs.writeShellApplication {
    name = "ns";

    runtimeInputs = with pkgs; [
      fzf
      nix-search-tv
    ];

    text = builtins.readFile "${pkgs.nix-search-tv.src}/nixpkgs.sh";
  };

  hex = lib.removePrefix "#";
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  koda = {
    # Wallpaper-sampled, Koda/Alabaster-style palette:
    # neutral first, blue for structure, rose/crimson for rare emphasis/errors.
    bg = "#10161b";
    bgAlt = "#151d23";
    surface = "#202930";
    surfaceAlt = "#28343c";
    fg = "#d8d6d1";
    white = "#f4ede9";
    muted = "#8f9194";
    subtle = "#596369";
    ink = "#174860";
    crimson = "#c8113a";
    salmon = "#cb2936";
    rose = "#e7b7b6";
    red = "#cc4f63";
    redBright = "#e06b7d";
    green = "#92b79c";
    greenSoft = "#a5c6aa";
    yellow = "#d7b56d";
    gold = "#d4a871";
    blue = "#8bb6c8";
    blueBright = "#a8c9d6";
    magenta = "#d899b1";
    magentaBright = "#e7b7b6";
    cyan = "#79b7c4";
    cyanBright = "#99cbd1";
  };

  # Native Nix builders for Zellij's KDL AST. This keeps the config declarative
  # while still emitting the exact duplicate KDL nodes Zellij expects.
  znode = name: args: {${name} = {_args = args;};};
  zunit = name: {${name} = {};};
  zaction = znode;
  zswitch = mode: zaction "SwitchToMode" [mode];
  zbind = keys: actions: {
    bind = {
      _args = keys;
      _children = actions;
    };
  };
  zplugin = location: {
    LaunchOrFocusPlugin = {
      _args = [location];
      floating = true;
      move_to_focused_tab = true;
    };
  };
in {
  imports = [
    inputs.nixvim.homeModules.nixvim
    inputs.spicetify-nix.homeManagerModules.spicetify
  ];

  home = {
    stateVersion = "26.05";

    packages = with pkgs; [
      # Process / system inspection
      procs
      dust
      bottom
      bandwhich
      tokei
      hyperfine
      watchexec

      # Networking / transfer
      xh
      aria2

      # Unix replacements and data tooling
      betterdisplay
      jaq
      jq
      sd
      tealdeer
      just

      # Nix
      nixd
      alejandra
      deadnix
      statix
      # nix-output-monitor
      # nvd
      ns

      # Rust nightly fallback toolchain. Project devShells/direnv should still
      # win when present.
      (fenix.latest.withComponents [
        "cargo"
        "clippy"
        "rust-analyzer"
        "rust-src"
        "rustc"
        "rustfmt"
      ])

      # cargo-edit
      # cargo-expand
      # cargo-nextest
      # cargo-watch
      # bacon
      lazygit

      # spotify is already installed by spicetify-nix
      ghostty-bin
      raycast
    ];

    shell.enableFishIntegration = true;

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      MANPAGER = "sh -c 'col -bx | bat -l man -p'";
      PAGER = "less -FRX";
      BAT_THEME = "ansi";
      FZF_DEFAULT_COMMAND = "fd --type f --hidden --exclude .git";
      # Pastel Koda colors for eza: low-chroma dirs, rose errors, gold metadata.
      EZA_COLORS = builtins.concatStringsSep ":" [
        "di=38;2;139;182;200"
        "ex=38;2;165;198;170"
        "fi=38;2;216;214;209"
        "ln=38;2;121;183;196"
        "or=38;2;224;107;125"
        "mi=38;2;224;107;125"
        "pi=38;2;143;145;148"
        "so=38;2;143;145;148"
        "bd=38;2;212;168;113"
        "cd=38;2;212;168;113"
        "ur=38;2;224;107;125"
        "uw=38;2;212;168;113"
        "ux=38;2;165;198;170"
        "gr=38;2;143;145;148"
        "gw=38;2;143;145;148"
        "tr=38;2;143;145;148"
        "tw=38;2;143;145;148"
      ];
      HOMEBREW_NO_ANALYTICS = "1";
      HOMEBREW_NO_AUTO_UPDATE = "1";
      RUST_BACKTRACE = "1";
    };

    file.".ssh/sockets/.keep".text = "";
  };

  programs = {
    nixvim = {
      enable = true;
      # package = pkgs.neovim-unwrapped;
      imports = [./nixvim.nix];
    };

    spicetify = {
      enable = true;
      # Let spicetify-nix own the Spotify wrapper and all patching. Do not
      # install pkgs.spotify or patch Spotify separately; adblocking is applied
      # through the packaged adblockify extension below.
      alwaysEnableDevTools = false;
      experimentalFeatures = true;

      enabledExtensions = with spicePkgs.extensions; [
        # Native spicetify-nix extension path for adblocking.
        adblockify

        # Small, high-value UX extensions. Avoid Marketplace/heavy visual extras.
        hidePodcasts
        shuffle
        keyboardShortcut
        fullAppDisplay
      ];

      enabledCustomApps = with spicePkgs.apps; [
        marketplace
      ];

      # Dribbblish gives the macOS-ish rounded shell; the custom scheme keeps it
      # visually aligned with Ghostty/Zellij/Nvim instead of drifting Catppuccin.
      theme = spicePkgs.themes.dribbblish;
      # customColorScheme is emitted under Spicetify's "custom" scheme.
      colorScheme = "custom";
      customColorScheme = {
        text = hex koda.white;
        subtext = hex koda.fg;
        main = hex koda.bg;
        sidebar = hex koda.bgAlt;
        player = hex koda.bg;
        card = hex koda.surface;
        shadow = hex koda.bg;
        "selected-row" = hex koda.surfaceAlt;
        # Wallpaper-aware accent: rose is emphasis, blue is navigation/active structure.
        button = hex koda.rose;
        "button-active" = hex koda.blue;
        "button-disabled" = hex koda.subtle;
        "tab-active" = hex koda.surfaceAlt;
        notification = hex koda.surface;
        "notification-error" = hex koda.redBright;
        misc = hex koda.muted;
      };
    };

    chromium = {
      enable = true;
      package = pkgs.brave;
      commandLineArgs = [
        "--enable-features=ParallelDownloading,OverlayScrollbar,BackForwardCache"
        "--no-first-run"
        "--no-default-browser-check"
      ];
      extensions = [
        {id = "eikknpnckalfaafkjkkjbikfbkbkdnfc";} # Zelix Secure Bookmarks
        {id = "eimadpbcbfnmbkopoojfekhnkhdbieeh";} # Dark Reader
        {id = "mnjggcdmjocbbbhaepdhchncahnbgone";} # SponsorBlock
        {id = "gebbhagfogifgggkldgodflihgfeippi";} # Return YouTube Dislike
        {id = "ponfpcnoihfmfllpaingbgckeeldkhle";} # Enhancer for YouTube
        {id = "pejdijmoenmkgeppbflobdenhhabjlaj";} # iCloud Passwords
      ];
    };

    ghostty = {
      enable = true;
      # Ghostty itself is installed by the Homebrew cask in default.nix; Home
      # Manager should own the config only. Nullable package is supported by HM.
      package = null;
      enableFishIntegration = true;
      installBatSyntax = false;
      installVimSyntax = false;

      settings = {
        "font-family" = [
          "JetBrainsMono Nerd Font Mono"
          "FiraCode Nerd Font Mono"
        ];
        "font-size" = 13.5;
        "font-synthetic-style" = false;
        "font-feature" = [
          "-calt"
          "-liga"
          "-dlig"
        ];

        background = koda.bg;
        foreground = koda.fg;
        palette = [
          "0=${koda.bg}"
          "1=${koda.red}"
          "2=${koda.greenSoft}"
          "3=${koda.gold}"
          "4=${koda.blue}"
          "5=${koda.magenta}"
          "6=${koda.cyan}"
          "7=${koda.fg}"
          "8=${koda.subtle}"
          "9=${koda.redBright}"
          "10=${koda.green}"
          "11=${koda.yellow}"
          "12=${koda.blueBright}"
          "13=${koda.magentaBright}"
          "14=${koda.cyanBright}"
          "15=${koda.white}"
        ];

        "cursor-color" = koda.rose;
        "cursor-style" = "block";
        "cursor-style-blink" = false;

        "selection-background" = koda.surfaceAlt;
        "selection-foreground" = koda.white;
        "split-divider-color" = koda.surface;
        "unfocused-split-opacity" = 1.0;

        "window-padding-x" = 8;
        "window-padding-y" = 6;
        "window-padding-balance" = true;
        "window-padding-color" = "background";
        "window-save-state" = "never";
        "window-vsync" = true;

        "window-theme" = "dark";
        "macos-titlebar-style" = "transparent";
        "macos-titlebar-proxy-icon" = "hidden";
        "macos-window-buttons" = "visible";
        "macos-window-shadow" = true;
        "macos-option-as-alt" = true;

        # Cheap liquid-glass: transparent native titlebar + tiny terminal opacity.
        # Blur stays off because it is the real compositor tax.
        "background-opacity" = 0.985;
        "background-blur" = false;

        "mouse-hide-while-typing" = true;
        "window-inherit-working-directory" = true;
        "tab-inherit-working-directory" = true;
      };
    };

    lazygit = {
      enable = true;
      settings = {
        gui.theme = {
          activeBorderColor = [koda.rose "bold"];
          inactiveBorderColor = [koda.subtle];
          optionsTextColor = [koda.blue];
          selectedLineBgColor = [koda.surfaceAlt];
          cherryPickedCommitBgColor = [koda.surface];
          cherryPickedCommitFgColor = [koda.rose];
          unstagedChangesColor = [koda.redBright];
          defaultFgColor = [koda.fg];
          searchingActiveBorderColor = [koda.blue];
          authorColors."*" = koda.white;
        };
      };
    };

    fish = {
      enable = true;
      preferAbbrs = true;
      interactiveShellInit = ''
        set -g fish_greeting

        # Keep universal variables from accumulating stale Nix profile paths.
        set -gx EDITOR nvim
        set -gx VISUAL nvim

        # Wallpaper-Koda fish palette. Alabaster-ish rule: only meaning gets color.
        # blue=structure/paths, rose=string/emphasis, gold=comments/warnings, red=errors.
        set -g fish_color_normal ${hex koda.fg}
        set -g fish_color_command ${hex koda.blue}
        set -g fish_color_keyword ${hex koda.fg}
        set -g fish_color_quote ${hex koda.rose}
        set -g fish_color_redirection ${hex koda.gold}
        set -g fish_color_end ${hex koda.muted}
        set -g fish_color_error ${hex koda.redBright}
        set -g fish_color_param ${hex koda.fg}
        set -g fish_color_comment ${hex koda.gold} --italics
        set -g fish_color_selection --background=${hex koda.surfaceAlt}
        set -g fish_color_search_match --background=${hex koda.surfaceAlt}
        set -g fish_color_operator ${hex koda.muted}
        set -g fish_color_escape ${hex koda.rose}
        set -g fish_color_autosuggestion ${hex koda.subtle}
        set -g fish_color_valid_path --underline ${hex koda.blue}
        set -g fish_pager_color_progress ${hex koda.muted}
        set -g fish_pager_color_prefix ${hex koda.blue}
        set -g fish_pager_color_completion ${hex koda.fg}
        set -g fish_pager_color_description ${hex koda.muted}

        # Feed useful, cheap context into zjstatus tab names.
        if set -q ZELLIJ
          function __koda_zellij_tab_preexec --on-event fish_preexec
            set -l cmd (string split -m 1 ' ' -- $argv)[1]
            switch $cmd
              case z cd zi zj za zh clear reset
                return
            end
            command zellij action rename-tab $cmd >/dev/null 2>&1 &
          end

          function __koda_zellij_tab_postexec --on-event fish_postexec
            set -l root (command git rev-parse --show-toplevel 2>/dev/null)
            if test -n "$root"
              command zellij action rename-tab (basename "$root") >/dev/null 2>&1 &
            else
              command zellij action rename-tab (basename "$PWD") >/dev/null 2>&1 &
            end
          end
        end
      '';
      shellAliases = {
        ls = "eza --icons=auto --group-directories-first";
        ll = "eza -al --icons=auto --group-directories-first --git";
        la = "eza -a --icons=auto --group-directories-first";
        tree = "eza --tree --icons=auto --group-directories-first";
        cat = "bat --style=plain";
        grep = "rg";
        find = "fd";
        top = "btm";
        du = "dust";
        ps = "procs";
        ".." = "cd ..";
        "..." = "cd ../..";
      };
      shellAbbrs = {
        g = "git";
        gs = "git status --short --branch";
        ga = "git add";
        gc = "git commit";
        gcm = "git commit -m";
        gp = "git push";
        gl = "git pull --rebase --autostash";
        gd = "git diff";
        gds = "git diff --staged";
        lg = "lazygit";
        za = "zellij attach --create --force-run-commands";
        zh = "nvim --cmd 'let g:nixvim_auto_session=1'";
        zl = "zellij list-sessions";
        nds = "nh darwin switch";
        ndt = "nh darwin test";
        ndu = "nix flake update";
        nfu = "nix flake update";
        ndev = "nix develop -c fish";
      };

      functions = {
        zj = {
          description = "Attach/create a project-named Zellij session";
          body = ''
            set -l name
            if test (count $argv) -gt 0
              set name $argv[1]
            else
              set -l root (command git rev-parse --show-toplevel 2>/dev/null)
              if test -n "$root"
                set name (basename "$root" | string replace -ra "[^A-Za-z0-9_.-]" "-")
              else
                set name (basename "$PWD" | string replace -ra "[^A-Za-z0-9_.-]" "-")
              end
            end

            command zellij attach --create --force-run-commands "$name"
          '';
        };
      };
    };

    # man.package is null
    man.generateCaches = false;

    starship = {
      enable = true;
      enableFishIntegration = true;
      presets = ["nerd-font-symbols"];
      settings = {
        add_newline = false;
        command_timeout = 450;
        scan_timeout = 16;
        palette = "koda";

        palettes.koda = {
          inherit (koda) bg surface fg white muted subtle gold blue magenta cyan rose;
          green = koda.greenSoft;
          red = koda.redBright;
          orange = koda.salmon;
        };

        # Pure-style: one context line, one input line. No right prompt/fill noise.
        # Version modules stay symbol-only to avoid prompt latency.
        format = "$directory$git_branch$git_status$cmd_duration$nix_shell$rust$nodejs$line_break$character";

        character = {
          success_symbol = "[❯](rose)";
          error_symbol = "[❯](red)";
          vimcmd_symbol = "[❮](blue)";
        };

        directory = {
          truncation_length = 3;
          truncation_symbol = "…/";
          fish_style_pwd_dir_length = 1;
          style = "blue";
          read_only = " 󰌾";
          read_only_style = "red";
          format = "[$path]($style)[$read_only]($read_only_style) ";
        };

        git_branch = {
          symbol = " ";
          style = "rose";
          format = "[$symbol$branch]($style) ";
        };

        git_status = {
          style = "red";
          ahead = "⇡\${count}";
          behind = "⇣\${count}";
          diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
          staged = "+\${count}";
          modified = "!\${count}";
          deleted = "✘\${count}";
          untracked = "?\${count}";
          renamed = "»\${count}";
          stashed = "*\${count}";
          format = "[$all_status$ahead_behind]($style) ";
        };

        cmd_duration = {
          min_time = 750;
          show_milliseconds = false;
          style = "subtle";
          format = "[$duration]($style) ";
        };

        nix_shell = {
          symbol = "";
          style = "cyan";
          format = "[$symbol]($style) ";
        };

        rust = {
          symbol = "";
          style = "rose";
          detect_files = ["Cargo.toml"];
          detect_extensions = [];
          format = "[$symbol]($style) ";
        };

        nodejs = {
          symbol = "";
          style = "blue";
          detect_files = ["package.json" "bun.lock" "bun.lockb" "pnpm-lock.yaml" "yarn.lock"];
          detect_extensions = [];
          format = "[$symbol]($style) ";
        };
      };
    };

    zoxide = {
      enable = true;
      enableFishIntegration = true;
      options = ["--cmd cd"];
    };

    fzf = {
      enable = true;
      enableFishIntegration = true;
      defaultCommand = "fd --type f --hidden --exclude .git";
      defaultOptions = [
        "--height=40%"
        "--layout=reverse"
        "--border=none"
        "--info=inline-right"
        "--highlight-line"
        "--ansi"
        "--cycle"
        "--bind=ctrl-d:half-page-down,ctrl-u:half-page-up"
        "--color=bg:${koda.bg},bg+:${koda.surface},gutter:${koda.bg}"
        "--color=fg:${koda.fg},fg+:${koda.white},query:${koda.fg}"
        "--color=hl:${koda.rose},hl+:${koda.rose},info:${koda.muted}"
        "--color=prompt:${koda.blue},pointer:${koda.rose},marker:${koda.rose},spinner:${koda.muted}"
      ];
    };

    direnv = {
      enable = true;
      enableFishIntegration = true;
      silent = true;
      package = pkgs.direnv.overrideAttrs {
        doCheck = false;
      };
      config = {
        global = {
          hide_env_diff = true;
          warn_timeout = "1m";
        };
      };
      nix-direnv = {
        enable = true;
      };
    };

    eza = {
      enable = true;
      icons = "auto";
      enableFishIntegration = true;
      git = true;
    };

    bat = {
      enable = true;
      config = {
        theme = "ansi";
        style = "numbers,changes,header";
        pager = "less -FR";
      };
    };

    fd.enable = true;

    ripgrep = {
      enable = true;
      arguments = [
        "--smart-case"
        "--hidden"
        "--glob=!.git"
      ];
    };
    ripgrep-all.enable = true;

    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "ansi";
        side-by-side = true;
        hyperlinks = true;
        keep-plus-minus-markers = false;
        file-style = "omit";
      };
    };

    git = {
      enable = true;
      # package = pkgs.gitFull;

      lfs = {
        enable = true;
        skipSmudge = false;
      };

      ignores = [
        ".DS_Store"
        ".direnv/"
        ".envrc.local"
        ".vscode/settings.local.json"
      ];

      settings = {
        alias = {
          st = "status --short --branch";
          co = "checkout";
          ci = "commit";
          br = "branch";
          df = "diff";
          lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
        };

        user = {
          email = "conor@crsche.com";
          name = "Conor Scheidt";
        };

        core = {
          editor = "nvim";
          fsmonitor = true;
          untrackedCache = true;
          preloadIndex = true;
          commitGraph = true;
          excludesFile = "~/.config/git/ignore";
        };

        feature = {
          manyFiles = true;
        };

        protocol = {
          version = 2;
        };

        gpg = {
          format = "ssh";
        };

        tag = {
          gpgSign = true;
          sort = "version:refname";
        };

        color.ui = "auto";
        column.ui = "auto";
        branch.sort = "-committerdate";

        init.defaultBranch = "main";

        pull = {
          rebase = true;
        };

        push = {
          autoSetupRemote = true;
          default = "simple";
          followTags = true;
        };

        rebase = {
          autoStash = true;
          updateRefs = true;
        };

        fetch = {
          prune = true;
          pruneTags = true;
          writeCommitGraph = true;
          parallel = 8;
        };

        submodule = {
          fetchJobs = 8;
          recurse = true;
        };

        diff = {
          algorithm = "histogram";
          colorMoved = "default";
        };

        merge = {
          conflictstyle = "zdiff3";
        };

        commit = {
          verbose = true;
        };

        rerere = {
          enabled = true;
        };

        transfer = {
          fsckObjects = true;
        };

        receive = {
          fsckObjects = true;
        };
      };

      signing = {
        key = "~/.ssh/id_ed25519_signing";
        signByDefault = true;
      };
    };
    zellij = {
      enable = true;

      # Do not auto-start Zellij in every Fish shell. Use `zj`/`za` manually.
      enableFishIntegration = false;
      attachExistingSession = false;
      exitShellOnExit = false;

      settings = {
        default_mode = "locked";
        default_shell = "${pkgs.fish}/bin/fish";
        default_layout = "default";
        theme = "koda-macos";

        on_force_close = "detach";
        simplified_ui = true;
        pane_frames = false;
        auto_layout = true;
        stacked_resize = true;
        mouse_mode = false;
        advanced_mouse_actions = false;
        mouse_hover_effects = false;
        show_startup_tips = false;
        show_release_notes = false;
        web_server = false;
        web_sharing = "disabled";

        copy_command = "pbcopy";
        copy_clipboard = "system";
        copy_on_select = true;
        scrollback_editor = "nvim";

        # Resurrection: keep commands/layouts, not viewport/scrollback blobs.
        session_serialization = true;
        pane_viewport_serialization = false;
        scrollback_lines_to_serialize = 0;
        serialization_interval = 10;
        scroll_buffer_size = 5000;

        styled_underlines = true;
        osc8_hyperlinks = true;
        support_kitty_keyboard_protocol = true;

        # Keep resurrected Neovim commands GC-proof on Nix.
        post_command_discovery_hook = "printf '%s\n' \"$RESURRECT_COMMAND\" | sed -E 's#/nix/store/[^ ]+/bin/nvim#nvim#g'";

        keybinds = {
          _props."clear-defaults" = true;

          locked._children = [
            (zbind ["Ctrl b"] [(zswitch "Tmux")])
          ];

          tmux._children = [
            (zbind ["Esc"] [(zswitch "Locked")])
            (zbind ["Ctrl b"] [(zaction "Write" [2]) (zswitch "Locked")])

            # Session lifecycle.
            (zbind ["d"] [(zunit "Detach") (zswitch "Locked")])
            (zbind ["Q"] [(zunit "Quit")])

            # Panes.
            (zbind ["\"" "-"] [(zaction "NewPane" ["Down"]) (zswitch "Locked")])
            (zbind ["%" "|"] [(zaction "NewPane" ["Right"]) (zswitch "Locked")])
            (zbind ["s"] [(zunit "NewStackedPane") (zswitch "Locked")])
            (zbind ["Enter"] [(zunit "NewPane") (zswitch "Locked")])
            (zbind ["x"] [(zunit "CloseFocus") (zswitch "Locked")])
            (zbind ["z"] [(zunit "ToggleFocusFullscreen") (zswitch "Locked")])
            (zbind ["f"] [(zunit "ToggleFloatingPanes") (zswitch "Locked")])
            (zbind ["e"] [(zunit "TogglePaneEmbedOrFloating") (zswitch "Locked")])
            (zbind ["r"] [(zswitch "RenamePane") (zaction "PaneNameInput" [0])])

            # Focus.
            (zbind ["h" "Left"] [(zaction "MoveFocus" ["Left"]) (zswitch "Locked")])
            (zbind ["j" "Down"] [(zaction "MoveFocus" ["Down"]) (zswitch "Locked")])
            (zbind ["k" "Up"] [(zaction "MoveFocus" ["Up"]) (zswitch "Locked")])
            (zbind ["l" "Right"] [(zaction "MoveFocus" ["Right"]) (zswitch "Locked")])
            (zbind ["o"] [(zunit "FocusNextPane") (zswitch "Locked")])

            # Resize.
            (zbind ["H"] [(zaction "Resize" ["Increase Left"]) (zswitch "Locked")])
            (zbind ["J"] [(zaction "Resize" ["Increase Down"]) (zswitch "Locked")])
            (zbind ["K"] [(zaction "Resize" ["Increase Up"]) (zswitch "Locked")])
            (zbind ["L"] [(zaction "Resize" ["Increase Right"]) (zswitch "Locked")])
            (zbind ["=" "+"] [(zaction "Resize" ["Increase"]) (zswitch "Locked")])
            (zbind ["_"] [(zaction "Resize" ["Decrease"]) (zswitch "Locked")])

            # Tabs.
            (zbind ["c"] [(zunit "NewTab") (zswitch "Locked")])
            (zbind [","] [(zswitch "RenameTab") (zaction "TabNameInput" [0])])
            (zbind ["p"] [(zunit "GoToPreviousTab") (zswitch "Locked")])
            (zbind ["n"] [(zunit "GoToNextTab") (zswitch "Locked")])
            (zbind ["Tab"] [(zunit "ToggleTab") (zswitch "Locked")])

            (zbind ["1"] [(zaction "GoToTab" [1]) (zswitch "Locked")])
            (zbind ["2"] [(zaction "GoToTab" [2]) (zswitch "Locked")])
            (zbind ["3"] [(zaction "GoToTab" [3]) (zswitch "Locked")])
            (zbind ["4"] [(zaction "GoToTab" [4]) (zswitch "Locked")])
            (zbind ["5"] [(zaction "GoToTab" [5]) (zswitch "Locked")])
            (zbind ["6"] [(zaction "GoToTab" [6]) (zswitch "Locked")])
            (zbind ["7"] [(zaction "GoToTab" [7]) (zswitch "Locked")])
            (zbind ["8"] [(zaction "GoToTab" [8]) (zswitch "Locked")])
            (zbind ["9"] [(zaction "GoToTab" [9]) (zswitch "Locked")])

            # Scroll/search and built-in plugin UIs.
            (zbind ["["] [(zswitch "Scroll")])
            (zbind ["w"] [(zplugin "session-manager") (zswitch "Locked")])
            (zbind ["F"] [(zplugin "zellij:strider") (zswitch "Locked")])
            (zbind ["P"] [(zplugin "plugin-manager") (zswitch "Locked")])
            (zbind ["C"] [(zplugin "configuration") (zswitch "Locked")])
          ];

          scroll._children = [
            (zbind ["Esc" "q"] [(zunit "ScrollToBottom") (zswitch "Locked")])
            (zbind ["e"] [(zunit "EditScrollback") (zswitch "Locked")])
            (zbind ["/"] [(zswitch "EnterSearch") (zaction "SearchInput" [0])])
            (zbind ["j" "Down"] [(zunit "ScrollDown")])
            (zbind ["k" "Up"] [(zunit "ScrollUp")])
            (zbind ["g"] [(zunit "ScrollToTop")])
            (zbind ["G"] [(zunit "ScrollToBottom")])
            (zbind ["Ctrl f" "PageDown"] [(zunit "PageScrollDown")])
            (zbind ["Ctrl b" "PageUp"] [(zunit "PageScrollUp")])
            (zbind ["d"] [(zunit "HalfPageScrollDown")])
            (zbind ["u"] [(zunit "HalfPageScrollUp")])
          ];

          entersearch._children = [
            (zbind ["Esc" "Ctrl c"] [(zswitch "Scroll")])
            (zbind ["Enter"] [(zswitch "Search")])
          ];

          search._children = [
            (zbind ["Esc" "Ctrl c"] [(zunit "ScrollToBottom") (zswitch "Locked")])
            (zbind ["j" "Down"] [(zunit "ScrollDown")])
            (zbind ["k" "Up"] [(zunit "ScrollUp")])
            (zbind ["n"] [(zaction "Search" ["down"])])
            (zbind ["p" "N"] [(zaction "Search" ["up"])])
            (zbind ["c"] [(zaction "SearchToggleOption" ["CaseSensitivity"])])
            (zbind ["w"] [(zaction "SearchToggleOption" ["Wrap"])])
            (zbind ["o"] [(zaction "SearchToggleOption" ["WholeWord"])])
          ];

          renametab._children = [
            (zbind ["Esc" "Ctrl c"] [(zunit "UndoRenameTab") (zswitch "Locked")])
            (zbind ["Enter"] [(zswitch "Locked")])
          ];

          renamepane._children = [
            (zbind ["Esc" "Ctrl c"] [(zunit "UndoRenamePane") (zswitch "Locked")])
            (zbind ["Enter"] [(zswitch "Locked")])
          ];
        };
      };

      themes."koda-macos" = {
        themes._children = [
          {
            "koda-macos"._children = [
              (znode "bg" [16 22 27])
              (znode "fg" [216 214 209])
              (znode "black" [16 22 27])
              (znode "white" [244 237 233])
              (znode "red" [204 79 99])
              (znode "green" [146 183 156])
              (znode "yellow" [215 181 109])
              (znode "blue" [139 182 200])
              (znode "magenta" [231 183 182])
              (znode "cyan" [121 183 196])
              (znode "orange" [212 168 113])
            ];
          }
        ];
      };

      layouts.default = {
        layout._children = [
          {
            default_tab_template._children = [
              {children = {};}
              {
                pane = {
                  _props = {
                    size = 1;
                    borderless = true;
                  };
                  _children = [
                    {
                      plugin = {
                        _props.location = "file://${pkgs.zjstatus}/bin/zjstatus.wasm";
                        _children = [
                          (znode "color_bg" [koda.bg])
                          (znode "color_bg_alt" [koda.bgAlt])
                          (znode "color_surface" [koda.surface])
                          (znode "color_fg" [koda.fg])
                          (znode "color_muted" [koda.muted])
                          (znode "color_red" [koda.red])
                          (znode "color_green" [koda.green])
                          (znode "color_yellow" [koda.yellow])
                          (znode "color_blue" [koda.blue])
                          (znode "color_gold" [koda.gold])
                          (znode "color_magenta" [koda.magenta])
                          (znode "color_cyan" [koda.cyan])
                          (znode "color_rose" [koda.rose])
                          (znode "color_subtle" [koda.subtle])

                          (znode "hide_frame_for_single_pane" ["true"])
                          (znode "border_enabled" ["false"])

                          (znode "format_left" [" {mode}{session}{tabs}"])
                          (znode "format_center" ["{command_git_branch}"])
                          (znode "format_right" ["{datetime} "])
                          (znode "format_space" ["#[bg=$bg]"])
                          (znode "format_hide_on_overlength" ["true"])
                          (znode "format_precedence" ["lrc"])

                          (znode "mode_locked" ["#[fg=$muted,bg=$bg] 󰌾 #[fg=$red,bg=$bg]●#[fg=$gold,bg=$bg]●#[fg=$blue,bg=$bg]● "])
                          (znode "mode_tmux" ["#[fg=$bg,bg=$rose,bold]  ⌘ #[fg=$rose,bg=$bg] "])
                          (znode "mode_normal" ["#[fg=$bg,bg=$blue,bold]  NORMAL #[fg=$blue,bg=$bg] "])
                          (znode "mode_resize" ["#[fg=$bg,bg=$gold,bold]  RESIZE #[fg=$gold,bg=$bg] "])
                          (znode "mode_pane" ["#[fg=$bg,bg=$cyan,bold]  PANE #[fg=$cyan,bg=$bg] "])
                          (znode "mode_tab" ["#[fg=$bg,bg=$rose,bold]  TAB #[fg=$rose,bg=$bg] "])
                          (znode "mode_scroll" ["#[fg=$bg,bg=$gold,bold]  SCROLL #[fg=$gold,bg=$bg] "])
                          (znode "mode_search" ["#[fg=$bg,bg=$gold,bold]  SEARCH #[fg=$gold,bg=$bg] "])
                          (znode "mode_enter_search" ["#[fg=$bg,bg=$gold,bold]  SEARCH #[fg=$gold,bg=$bg] "])
                          (znode "mode_default_to_mode" ["locked"])

                          (znode "session" ["#[fg=$blue,bg=$bg] {name} #[fg=$subtle,bg=$bg]│ "])
                          (znode "tab_normal" ["#[fg=$muted,bg=$bg] {index}:{name}{sync_indicator}{fullscreen_indicator}{floating_indicator} "])
                          (znode "tab_active" ["#[fg=$bg,bg=$blue,bold]#[fg=$bg,bg=$blue,bold] {index}:{name}{sync_indicator}{fullscreen_indicator}{floating_indicator} #[fg=$blue,bg=$bg] "])
                          (znode "tab_sync_indicator" [" "])
                          (znode "tab_fullscreen_indicator" [" 󰊓"])
                          (znode "tab_floating_indicator" [" 󰹙"])

                          (znode "command_git_branch_command" ["git branch --show-current 2>/dev/null"])
                          (znode "command_git_branch_format" ["#[fg=$rose,bg=$bg] {stdout}"])
                          (znode "command_git_branch_interval" ["10"])
                          (znode "command_git_branch_rendermode" ["static"])

                          (znode "datetime" ["#[fg=$muted,bg=$bg] 󰥔 {format}"])
                          (znode "datetime_format" ["%H:%M"])
                        ];
                      };
                    }
                  ];
                };
              }
            ];
          }
        ];
      };
    };
    nh = {
      enable = true;
      flake = "${config.home.homeDirectory}/dev/dots";
      clean = {
        enable = true;
        extraArgs = "--keep-since 7d --keep 3";
      };
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {
        "*" = {
          forwardAgent = false;
          addKeysToAgent = "yes";
          identityFile = "~/.ssh/id_ed25519";
          identitiesOnly = true;
          serverAliveInterval = 30;
          serverAliveCountMax = 3;
          controlMaster = "auto";
          controlPersist = "10m";
          controlPath = "~/.ssh/sockets/%C";
          hashKnownHosts = true;
          extraOptions = {
            UseKeychain = "yes";
          };
        };

        "github.com" = {
          hostname = "github.com";
          user = "git";
          identityFile = "~/.ssh/id_ed25519";
          identitiesOnly = true;
          addKeysToAgent = "yes";
          extraOptions = {
            UseKeychain = "yes";
          };
        };
      };
    };
  };
}
