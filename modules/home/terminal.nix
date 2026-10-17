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
      command = "${pkgs.fish}/bin/fish --login -c 'exec ${tmux} new-session -A -s main'";
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

      window-padding-x = 6;
      window-padding-y = 2;
      window-padding-balance = true;
      window-padding-color = "extend";
      window-save-state = "never";
      macos-titlebar-style = "hidden"; # tmux shows the session; Ctrl-Cmd-drag moves windows
      macos-icon = "custom-style";
      macos-icon-ghost-color = c.fg;
      macos-icon-screen-color = c.bg0;
      resize-overlay = "never";
      macos-option-as-alt = true;
      background-opacity = 0.985;
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
    extraConfig = ''
      set -s extended-keys on
      set -s extended-keys-format csi-u
      set -as terminal-features ',xterm-ghostty:RGB:extkeys:usstyle:clipboard:sync:hyperlinks:focus:cstyle'
      set -g set-clipboard on
      set -g allow-passthrough on
      set -g detach-on-destroy off
      set -g renumber-windows on
      set -g set-titles on
      set -g set-titles-string '#S · #W'
      set -g automatic-rename-format '#{?#{==:#{pane_current_command},fish},#{b:pane_current_path},#{pane_current_command}}'

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
      bind -T copy-mode-vi y send -X copy-selection-and-cancel

      # Project sessions: tmux sessions plus zoxide directories.
      bind s display-popup -E -w 60% -h 50% -b rounded -S 'fg=${c.bg3}' \
        "sesh connect \"\$(sesh list --icons | fzf --ansi --no-sort --prompt 'session  ' --height 100%)\""

      set -g status-position bottom
      set -g status-justify left
      set -g status-style 'bg=${c.bg0},fg=${c.grey1}'
      set -g status-left-length 40
      set -g status-left '#[fg=${c.bg0},bg=${c.blue},bold] #S #[bg=${c.bg0}] '
      set -g status-right '#{?client_prefix,#[fg=${c.orange}]prefix ,}#[fg=${c.grey0}]%H:%M '
      setw -g window-status-format '#[fg=${c.grey1}] #I #W '
      setw -g window-status-current-format '#[fg=${c.fg},bg=${c.bg3}] #I #W '
      setw -g window-status-separator ""
      set -g pane-border-style 'fg=${c.bg3}'
      set -g pane-active-border-style 'fg=${c.orange}'
      set -g message-style 'bg=${c.bg1},fg=${c.fg}'
      set -g mode-style 'bg=${c.bg3},fg=${c.fg}'
      set -g popup-border-style 'fg=${c.bg3}'
      set -g clock-mode-colour '${c.blue}'
    '';
  };
}
