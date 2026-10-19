# One pane model: Ghostty renders, tmux owns windows/panes/sessions, and
# Ctrl-h/j/k/l moves across tmux panes and Neovim splits (smart-splits.nvim
# marks Neovim panes with @pane-is-vim, so no per-keypress `ps`).
{
  config,
  pkgs,
  ...
}: let
  c = import ../theme.nix;
  tmux = "${config.programs.tmux.package}/bin/tmux";
  # Cmd shortcuts drive tmux through its prefix (C-b).
  toTmux = key: seq: "${key}=text:\\x02${seq}";
in {
  home.packages = [pkgs.sesh];

  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;
    enableFishIntegration = false; # Ghostty injects its integration itself
    settings = {
      # Login shell first so the tmux server inherits the full Nix environment.
      command = "${pkgs.fish}/bin/fish --login -c 'exec ${tmux} -u new-session -A -s main'";
      # Its injection is consumed by the non-interactive wrapper above, and
      # tmux owns titles and prompts anyway.
      shell-integration = "none";

      font-family = "FiraCode Nerd Font Mono";
      font-size = 13.5;
      font-feature = ["calt" "liga" "ss01" "ss03"];

      background = c.bg0;
      foreground = c.fg;
      cursor-color = c.orange;
      cursor-text = c.bg0;
      cursor-style-blink = false;
      selection-background = c.bg3;
      selection-foreground = c.fg;
      palette = [
        "0=${c.bg5}"
        "1=${c.red}"
        "2=${c.green}"
        "3=${c.yellow}"
        "4=${c.blue}"
        "5=${c.purple}"
        "6=${c.aqua}"
        "7=${c.fg}"
        "8=${c.grey1}"
        "9=${c.red}"
        "10=${c.green}"
        "11=${c.yellow}"
        "12=${c.blue}"
        "13=${c.purple}"
        "14=${c.aqua}"
        "15=${c.fg}"
      ];

      # Padding stays the background colour: "extend" would smear tmux's
      # status-bar colours into the margins.
      window-padding-x = 12;
      window-padding-y = 8;
      window-padding-balance = true;
      window-padding-color = "background";
      window-save-state = "never";
      macos-titlebar-style = "hidden"; # tmux shows the session; Ctrl-Cmd-drag moves windows
      macos-icon = "custom-style";
      macos-icon-ghost-color = c.fg;
      macos-icon-screen-color = c.bg0;
      resize-overlay = "never";
      macos-option-as-alt = true;
      mouse-hide-while-typing = true;
      auto-update = "off"; # Nix owns the app
      app-notifications = "no-clipboard-copy";
      confirm-close-surface = false; # closing a window only detaches tmux

      keybind = [
        (toTmux "super+t" "c")
        (toTmux "super+d" "|")
        (toTmux "super+shift+d" "-")
        (toTmux "super+w" "x")
        (toTmux "super+shift+left_bracket" "p")
        (toTmux "super+shift+right_bracket" "n")
        (toTmux "super+k" "s")
        (toTmux "super+g" "g")
        (toTmux "super+digit_1" "1")
        (toTmux "super+digit_2" "2")
        (toTmux "super+digit_3" "3")
        (toTmux "super+digit_4" "4")
        (toTmux "super+digit_5" "5")
        (toTmux "super+digit_6" "6")
        (toTmux "super+digit_7" "7")
        (toTmux "super+digit_8" "8")
        (toTmux "super+digit_9" "9")
      ];
    };
  };

  programs.tmux = {
    enable = true;
    shell = "${pkgs.fish}/bin/fish";
    terminal = "tmux-256color";
    keyMode = "vi";
    mouse = true;
    escapeTime = 10;
    historyLimit = 50000;
    baseIndex = 1;
    focusEvents = true;
    aggressiveResize = true;
    plugins = [
      {
        # prefix F: hint-select any URL, path, hash or number on screen and copy it.
        plugin = pkgs.tmuxPlugins.fingers;
        extraConfig = ''
          # fingers only parses named/indexed colours; Ghostty maps these to
          # the Gruvbox Material palette (colour8 = grey).
          set -g @fingers-key F
          set -g @fingers-hint-style 'fg=red,bold'
          set -g @fingers-highlight-style 'fg=yellow'
          set -g @fingers-selected-hint-style 'fg=green,bold'
          set -g @fingers-selected-highlight-style 'fg=green'
          set -g @fingers-backdrop-style 'fg=colour8'
        '';
      }
    ];
    extraConfig = ''
      # Terminal: Ghostty's capabilities, clipboard over OSC 52, focus events.
      set -s extended-keys on
      set -s extended-keys-format csi-u
      set -as terminal-features ',xterm-ghostty:RGB:extkeys:usstyle:clipboard:sync:hyperlinks:focus:cstyle'
      set -g set-clipboard on
      set -g allow-passthrough on

      # Behaviour.
      set -g detach-on-destroy off
      set -g renumber-windows on
      set -g display-time 1500
      set -g set-titles on
      set -g set-titles-string '#S · #W'
      setw -g monitor-activity on
      set -g visual-activity off
      # Windows are named after their directory while a shell or Neovim runs in
      # them, after the command otherwise.
      set -g automatic-rename-format '#{?#{m/r:^(fish|nvim)$,#{pane_current_command}},#{?#{==:#{pane_current_path},${config.home.homeDirectory}},~,#{b:pane_current_path}},#{pane_current_command}}'

      # Ctrl-h/j/k/l: Neovim splits first, then tmux panes.
      bind -n C-h if -F '#{@pane-is-vim}' 'send-keys C-h' 'select-pane -L'
      bind -n C-j if -F '#{@pane-is-vim}' 'send-keys C-j' 'select-pane -D'
      bind -n C-k if -F '#{@pane-is-vim}' 'send-keys C-k' 'select-pane -U'
      bind -n C-l if -F '#{@pane-is-vim}' 'send-keys C-l' 'select-pane -R'
      bind -T copy-mode-vi C-h select-pane -L
      bind -T copy-mode-vi C-j select-pane -D
      bind -T copy-mode-vi C-k select-pane -U
      bind -T copy-mode-vi C-l select-pane -R
      bind C-l send-keys C-l

      bind | split-window -h -c '#{pane_current_path}'
      bind - split-window -v -c '#{pane_current_path}'
      bind c new-window -c '#{pane_current_path}'
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5
      bind r source-file ~/.config/tmux/tmux.conf \; display 'reloaded'
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi C-v send -X rectangle-toggle
      bind -T copy-mode-vi y send -X copy-selection-and-cancel

      # Popups: project sessions (tmux sessions + zoxide dirs), lazygit, scratch shell.
      bind s display-popup -E -w 60% -h 50% \
        "sesh connect \"\$(sesh list --icons | fzf --ansi --no-sort --prompt '  ' --height 100%)\""
      bind g display-popup -E -w 90% -h 85% -d '#{pane_current_path}' lazygit
      bind t display-popup -E -w 80% -h 70% -d '#{pane_current_path}'

      # Look: one flat bar on top (a tab bar under Ghostty's hidden titlebar,
      # clear of Neovim's statusline), colour carries state, no blocks.
      set -g status-position top
      set -g status-justify left
      set -g status-style 'bg=default,fg=${c.grey1}'
      set -g status-left-length 32
      set -g status-left '#[fg=${c.blue},bold]#S#[fg=${c.bg5},nobold]  │  '
      setw -g window-status-format '#[fg=${c.grey0}]#I #[fg=${c.grey1}]#W'
      setw -g window-status-current-format '#[fg=${c.orange}]#I #[fg=${c.fg},bold]#W#{?window_zoomed_flag,#[fg=${c.yellow}#,nobold] 󰁌,}'
      setw -g window-status-separator '   '
      setw -g window-status-activity-style 'fg=${c.yellow}'
      setw -g window-status-bell-style 'fg=${c.red}'
      set -g status-right-length 40
      set -g status-right '#{?client_prefix,#[fg=${c.orange}]prefix  ,}#{?pane_in_mode,#[fg=${c.yellow}]#{pane_mode}  ,}#[fg=${c.grey0}]%H:%M'

      set -g pane-border-lines single
      set -g pane-border-style 'fg=${c.bg3}'
      set -g pane-active-border-style 'fg=${c.orange}'
      set -g display-panes-colour '${c.grey1}'
      set -g display-panes-active-colour '${c.orange}'
      set -g message-style 'bg=${c.bg1},fg=${c.fg}'
      set -g message-command-style 'bg=${c.bg1},fg=${c.fg}'
      set -g mode-style 'bg=${c.bg3},fg=${c.fg}'
      set -g copy-mode-match-style 'bg=${c.bg3},fg=${c.yellow}'
      set -g copy-mode-current-match-style 'bg=${c.orange},fg=${c.bg0}'
      set -g popup-style 'bg=${c.bg0}'
      set -g popup-border-style 'fg=${c.bg5}'
      set -g popup-border-lines rounded
      set -g menu-style 'bg=${c.bg1},fg=${c.fg}'
      set -g menu-selected-style 'bg=${c.bg3},fg=${c.fg}'
      set -g menu-border-style 'fg=${c.bg5}'
      set -g menu-border-lines rounded
      set -g clock-mode-colour '${c.blue}'
    '';
  };
}
