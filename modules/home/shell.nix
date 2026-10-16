{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = import ../theme.nix;
  hex = lib.removePrefix "#";
  rgb =
    color:
    let
      h = hex color;
      byte = i: toString (lib.fromHexString (builtins.substring i 2 h));
    in
    "38;2;${byte 0};${byte 2};${byte 4}";

  # `direnv hook fish` and `zoxide init fish` print static code, so run them
  # once per build instead of in every shell (about 10 ms per launch).
  hook = name: command: pkgs.runCommand "${name}.fish" { } "${command} > $out";
  direnvHook = hook "direnv-hook" "${lib.getExe pkgs.direnv} hook fish";
  zoxideInit = hook "zoxide-init" "${lib.getExe pkgs.zoxide} init fish --cmd cd";
in
{
  home.packages = with pkgs; [
    ast-grep
    dust
    procs
    hyperfine
    tokei
    glow
    jq
    mosh
    rsync # Apple's openrsync rejects --info=progress2 (rcp)
    darwin.trash
  ];

  programs = {
    fish = {
      enable = true;
      plugins = map (p: { inherit (p) name src; }) (
        with pkgs.fishPlugins;
        [
          hydro
          fzf-fish
          autopair
          sponge
          puffer
        ]
      );
      # Man-page completions rebuild locally on most updates; fish and the
      # packages themselves already complete the tools in use.
      generateCompletions = false;
      shellInit = ''
        fish_add_path --global --append --path ~/.local/bin
      '';
      interactiveShellInit = ''
        # Set the variable rather than calling the function so plugins that
        # bind on its change event (autopair, puffer) bind vi insert mode too.
        set -g fish_key_bindings fish_vi_key_bindings
        set -g fish_greeting
        set -g fish_color_normal ${hex c.fg}
        set -g fish_color_command ${hex c.blue}
        set -g fish_color_keyword ${hex c.aqua}
        set -g fish_color_quote ${hex c.green}
        set -g fish_color_redirection ${hex c.yellow}
        set -g fish_color_end ${hex c.grey1}
        set -g fish_color_error ${hex c.red}
        set -g fish_color_param ${hex c.fg}
        set -g fish_color_option ${hex c.fg}
        set -g fish_color_comment ${hex c.grey0} --italics
        set -g fish_color_operator ${hex c.orange}
        set -g fish_color_escape ${hex c.orange}
        set -g fish_color_autosuggestion ${hex c.grey0}
        set -g fish_color_valid_path --underline
        set -g fish_color_selection --background=${hex c.bg3}
        set -g fish_color_search_match --background=${hex c.bg3}
        set -g fish_pager_color_progress ${hex c.grey1}
        set -g fish_pager_color_prefix ${hex c.blue}
        set -g fish_pager_color_completion ${hex c.fg}
        set -g fish_pager_color_description ${hex c.grey1}
        set -g fish_pager_color_selected_background --background=${hex c.bg3}
        set -g hydro_color_pwd ${hex c.blue}
        set -g hydro_color_git ${hex c.orange}
        set -g hydro_color_error ${hex c.red}
        set -g hydro_color_prompt ${hex c.orange}
        set -g hydro_color_duration ${hex c.grey0}
        set -g hydro_symbol_prompt ❯
        set -g hydro_symbol_git_dirty " ●"
        set -g hydro_symbol_git_ahead " ⇡"
        set -g hydro_symbol_git_behind " ⇣"
        set -g hydro_cmd_duration_threshold 750
        set -g fish_prompt_pwd_dir_length 1
        set -g fish_vi_force_cursor 1
        set -g fish_cursor_default block
        set -g fish_cursor_insert line
        set -g fish_cursor_replace_one underscore
        set -g fish_cursor_visual block
        set -gx fzf_preview_dir_cmd eza --all --icons=always --color=always
        set -gx fzf_preview_file_cmd bat --style=numbers --color=always
        set -g fzf_diff_highlighter delta --paging=never
        set -g fzf_fd_opts --hidden --exclude=.git
        source ${direnvHook}
        source ${zoxideInit}
      '';
      functions = {
        mkcd = {
          description = "Create a directory and enter it";
          body = "mkdir -p $argv[1]; and cd $argv[1]";
        };
        help = {
          description = "Highlight command --help output with bat";
          body = ''
            $argv --help 2>&1 | bat --language=help --style=plain
          '';
        };
        fish_mode_prompt = "";
        fish_user_key_bindings = ''
          for mode in default insert visual
            bind -M $mode ctrl-f accept-autosuggestion
            bind -M $mode right accept-autosuggestion
            bind -M $mode alt-f forward-word
          end
          # Ctrl-T files and Ctrl-R history; lazygit covers the git pickers.
          fzf_configure_bindings --directory=ctrl-t --git_log= --git_status= --processes= --variables=
          bind -M insert ctrl-g rfv
          bind -M default ctrl-g rfv
        '';
        fish_right_prompt = ''
          set -q IN_NIX_SHELL; and printf '%s%s ' (set_color ${hex c.aqua}) 
          test -e Cargo.toml; and printf '%s%s ' (set_color ${hex c.orange}) 
          set_color normal
        '';
        # Two-stage interactive ripgrep <-> fzf switcher (Ctrl-G or `rfv`)
        # Ctrl-T toggles between Ripgrep live regex and fzf fuzzy filtering; Enter opens in nvim
        rfv = {
          description = "Interactive Ripgrep <-> fzf live search with bat preview";
          body = ''
            set -l rg_prefix "rg --column --line-number --no-heading --color=always --smart-case --"
            set -l initial_query "$argv"
            set -lx SHELL (status fish-path)
            set -lx rfv_state_dir (mktemp -d); or return
            printf '%s' "$initial_query" > "$rfv_state_dir/r"
            printf '%s' "" > "$rfv_state_dir/f"
            fzf --ansi --disabled --query "$initial_query" \
              --bind "start:reload:$rg_prefix {q} || true" \
              --bind "change:reload:sleep 0.05; $rg_prefix {q} || true" \
              --bind 'ctrl-t:transform:if not string match -q "*ripgrep*" $FZF_PROMPT; echo "rebind(change)+change-prompt(1. ripgrep> )+disable-search+transform-query:printf %s \{q} > \$rfv_state_dir/f; command cat \$rfv_state_dir/r"; else; echo "unbind(change)+change-prompt(2. fzf> )+enable-search+transform-query:printf %s \{q} > \$rfv_state_dir/r; command cat \$rfv_state_dir/f"; end' \
              --color "hl:-1:underline,hl+:-1:underline:reverse" \
              --prompt '1. ripgrep> ' \
              --delimiter : \
              --header 'Ctrl-T: Switch between ripgrep/fzf | Enter: Open in Neovim' \
              --preview 'bat --color=always --highlight-line {2} -- {1}' \
              --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
              --bind 'enter:become(nvim +{2} -- {1})'
            set -l fzf_status $status
            command rm -rf -- "$rfv_state_dir"
            return $fzf_status
          '';
        };
      };
      shellAbbrs = {
        g = "git";
        gs = "git status --short --branch";
        ga = "git add";
        gc = "git commit";
        gcm = "git commit -m";
        gac = {
          setCursor = true;
          expansion = "git add -A && git commit -m \"%\"";
        };
        gp = "git push";
        gl = "git pull";
        gd = "git diff";
        t = "tmux";
        m = "mosh";
        rm = "trash";
        rmf = "command rm -rf";
        nds = "nh darwin switch";
        ndb = "nh darwin build";
        ndu = "nh darwin switch --update --ask";
        npa = "nix profile add nixpkgs#";
        npr = "nix profile remove";
        npl = "nix profile list";
        ua = "uv add";
        ur = "uv run";
        cx = "cargo xtask";
        br = "bun run";
        bx = "bunx";
        bi = "bun install";
        ba = "bun add";
        bad = "bun add -D";
        brm = "bun remove";
        bt = "bun test";
      };
      # Aliases do NOT expand inline in the prompt (zero visual clutter)
      shellAliases = {
        cat = "bat --style=plain --paging=never";
        top = "btm";
        du = "dust";
        ps = "procs";
        ls = "eza --group-directories-first";
        ll = "eza -al --group-directories-first --git";
        la = "eza -a --group-directories-first";
        lt = "eza --tree --group-directories-first";
      };
    };

    eza = {
      enable = true;
      icons = "auto";
      git = true;
      enableFishIntegration = false;
    };

    bat = {
      enable = true;
      config = {
        theme = "ansi";
        style = "numbers,changes,header";
      };
    };

    fd = {
      enable = true;
      hidden = true;
      ignores = [
        ".git/"
        ".direnv/"
        ".venv/"
        "node_modules/"
        "target/"
        ".cache/"
        ".Trash/"
        ".cargo/registry/"
        ".npm/"
        ".bun/"
      ];
    };
    ripgrep = {
      enable = true;
      arguments = [
        "--smart-case"
        "--hidden"
        "--glob=!.git"
        "--glob=!.direnv"
        "--glob=!.venv"
        "--glob=!node_modules"
        "--glob=!target"
        "--glob=!.cache"
      ];
    };

    fzf = {
      enable = true;
      enableFishIntegration = false;
      # Run by $SHELL -c, where the interactive fd alias doesn't apply.
      defaultCommand = "fd --type f --hidden --strip-cwd-prefix";
      defaultOptions = [
        "--height=40%"
        "--layout=reverse"
        "--border=none"
        "--info=inline-right"
        "--highlight-line"
        "--cycle"
        "--color=bg:${c.bg0},bg+:${c.bg1},gutter:${c.bg0},fg:${c.fg},fg+:${c.fg},hl:${c.orange},hl+:${c.orange}"
        "--color=info:${c.grey1},prompt:${c.blue},pointer:${c.orange},marker:${c.green},spinner:${c.grey1},header:${c.grey1},border:${c.bg3}"
      ];
    };

    # Both hooks are generated at build time (see fish.interactiveShellInit).
    zoxide = {
      enable = true;
      enableFishIntegration = false;
    };

    direnv = {
      enable = true;
      enableFishIntegration = false;
      nix-direnv.enable = true;
      silent = true;
      config.global.warn_timeout = "1m";
    };

    bottom = {
      enable = true;
      settings = {
        processes = {
          default_grouped = true;
          default_memory_value = true;
        };
        styles = {
          widgets.selected_text = {
            color = c.bg0;
            bg_color = c.orange;
          };
          graphs.legend_text.color = c.fg;
          cpu.all_entry_color = c.fg;
          memory = {
            ram_color = c.blue;
            swap_color = c.yellow;
          };
          network = {
            rx_color = c.green;
            tx_color = c.purple;
          };
          tables.headers.color = c.orange;
        };
      };
    };
  };

  # The package's vendor conf.d hook also runs in non-interactive fish; this
  # user file masks it by name, leaving the interactive hook below.
  xdg.configFile."fish/conf.d/direnv.fish".text = "";

  # zoxide's default only skips $HOME; build trees and scratch directories
  # otherwise outrank real projects.
  home.sessionVariables._ZO_EXCLUDE_DIRS = lib.concatStringsSep ":" [
    config.home.homeDirectory
    "/tmp/*"
    "/private/tmp/*"
    "/nix/store/*"
    "*/target/*"
    "*/node_modules/*"
  ];

  home.sessionVariables.EZA_COLORS = lib.concatStringsSep ":" [
    "di=${rgb c.blue}"
    "ex=${rgb c.green}"
    "fi=${rgb c.fg}"
    "ln=${rgb c.aqua}"
    "or=${rgb c.red}"
    "mi=${rgb c.red}"
    "pi=${rgb c.grey1}"
    "so=${rgb c.grey1}"
    "bd=${rgb c.yellow}"
    "cd=${rgb c.yellow}"
    "ur=${rgb c.red}"
    "uw=${rgb c.yellow}"
    "ux=${rgb c.green}"
    "gr=${rgb c.grey1}"
    "gw=${rgb c.grey1}"
    "tr=${rgb c.grey1}"
    "tw=${rgb c.grey1}"
    "da=${rgb c.grey0}"
    "sn=${rgb c.aqua}"
    "sb=${rgb c.grey1}"
  ];
}
