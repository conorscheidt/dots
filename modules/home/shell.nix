{
  lib,
  pkgs,
  ...
}: let
  c = import ../theme.nix;
  hex = lib.removePrefix "#";
  rgb = color: let
    h = hex color;
    byte = i: toString (lib.fromHexString (builtins.substring i 2 h));
  in "38;2;${byte 0};${byte 2};${byte 4}";
in {
  home.packages = with pkgs; [
    dust
    procs
    hyperfine
    tokei
    glow
    jq
    mosh
  ];

  programs = {
    fish = {
      enable = true;
      plugins = map (p: {inherit (p) name src;}) (with pkgs.fishPlugins; [
        hydro # async prompt
        fzf-fish # Ctrl-R history, Ctrl-Alt-F files, Alt-C dirs
        fifc # fzf Tab completion with previews
        autopair
        sponge # failed commands stay out of history
        puffer # !! and !$ expansion
      ]);

      shellInit = ''
        # Ad-hoc `cargo install` / `uv tool` binaries, after every Nix path.
        fish_add_path --global --append --path ~/.local/bin ~/.cargo/bin
      '';

      interactiveShellInit = ''
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
        set -g hydro_fetch true
        set -g hydro_cmd_duration_threshold 750
        set -g fish_prompt_pwd_dir_length 1

        set -g fish_vi_force_cursor 1
        set -g fish_cursor_default block
        set -g fish_cursor_insert line
        set -g fish_cursor_replace_one underscore
        set -g fish_cursor_visual block

        set -g fzf_preview_dir_cmd eza --all --icons=always --color=always
        set -g fzf_preview_file_cmd bat --style=numbers --color=always
        set -g fzf_diff_highlighter delta --paging=never --width=20
        set -g fzf_fd_opts --hidden --exclude=.git
        set -g fifc_editor nvim
        set -g fifc_fd_opts --hidden --exclude=.git
      '';

      functions = {
        fish_user_key_bindings = ''
          fish_vi_key_bindings
          for mode in default insert visual
            bind -M $mode ctrl-f accept-autosuggestion
            bind -M $mode right accept-autosuggestion
            bind -M $mode alt-f forward-word
          end
          # Ctrl-V stays literal-insert; the variable picker moves to Ctrl-Alt-V.
          fzf_configure_bindings --variables=ctrl-alt-v
        '';

        # Nix shell and Cargo markers, computed without forking.
        fish_right_prompt = ''
          set -q IN_NIX_SHELL; and printf '%s%s ' (set_color ${hex c.aqua}) 
          test -e Cargo.toml; and printf '%s%s ' (set_color ${hex c.orange}) 
          set_color normal
        '';

        # Finder Trash (Put Back works); flags are ignored so `rm -rf x` still trashes.
        rm = {
          description = "Move paths to the Trash (use `command rm` to unlink)";
          body = ''
            set -l paths (string match -v -- '-*' $argv)
            test (count $paths) -gt 0; or return 1
            /usr/bin/trash $paths
          '';
        };
      };

      shellAbbrs = {
        g = "git";
        gs = "git status --short --branch";
        ga = "git add";
        gc = "git commit";
        gcm = "git commit -m";
        gp = "git push";
        gl = "git pull";
        gd = "git diff";
        gds = "git diff --staged";
        t = "tmux";
        m = "mosh";
        rmf = "command rm -rf";
        rcp = "rsync -ahP --info=progress2 --partial";
        nds = "nh darwin switch";
        ndb = "nh darwin build";
        ndu = "nh darwin switch --update";
        ndev = "nix develop -c fish";
        ns = "nh search";
        npa = "nix profile add nixpkgs#";
        npr = "nix profile remove";
        npl = "nix profile list";
        br = "bun run";
        bx = "bunx";
        cat = "bat --style=plain --paging=never";
        top = "btm";
        du = "dust";
        ps = "procs";
      };

      shellAliases = {
        ls = "eza --group-directories-first";
        ll = "eza -al --group-directories-first --git";
        la = "eza -a --group-directories-first";
        lt = "eza --tree --group-directories-first";
        ".." = "cd ..";
        "..." = "cd ../..";
      };
    };

    eza = {
      enable = true;
      icons = "auto";
      git = true;
      enableFishIntegration = false; # its abbrs would shadow the aliases above
    };

    bat = {
      enable = true;
      config = {
        theme = "ansi"; # follows the terminal's Gruvbox Material palette
        style = "numbers,changes,header";
      };
    };

    fd = {
      enable = true;
      hidden = true;
      ignores = [".git/"];
    };

    ripgrep = {
      enable = true;
      arguments = ["--smart-case" "--hidden" "--glob=!.git"];
    };

    fzf = {
      enable = true;
      enableFishIntegration = false; # fzf-fish owns the key bindings
      defaultCommand = "fd --type f";
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

    zoxide = {
      enable = true;
      options = ["--cmd cd"];
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
      silent = true;
      config.global = {
        hide_env_diff = true;
        warn_timeout = "1m";
      };
    };

    bottom = {
      enable = true;
      settings = {
        flags = {
          group_processes = true;
          mem_as_value = true;
          temperature_type = "c";
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
