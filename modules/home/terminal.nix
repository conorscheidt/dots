{
  config,
  pkgs,
  ...
}:
let
  c = import ../theme.nix;
  tmux = "${config.programs.tmux.package}/bin/tmux";
  reattach = "${pkgs.pam-reattach}/bin/reattach-to-session-namespace";
  toTmux = key: seq: "${key}=text:\\x02${seq}";
  # The key scheme on one page: `keys`, or Cmd-/ from anywhere. KEYS.md with
  # its Markdown markers turned into colour.
  keysPage = pkgs.runCommand "keys.txt" { } ''
    ${pkgs.gnused}/bin/sed -E \
      -e 's/^# (.*)/\x1b[1;33m\1\x1b[0m/' \
      -e 's/^## (.*)/\x1b[1;36m\1\x1b[0m/' \
      -e 's/`([^`]*)`/\x1b[32m\1\x1b[0m/g' ${../../KEYS.md} > $out
  '';
  keys = pkgs.writeShellScriptBin "keys" ''
    exec ${pkgs.less}/bin/less -R -Ps' q close   / search' ${keysPage}
  '';
in
{
  home.packages = [
    pkgs.sesh
    keys
  ];

  # A project opened from the picker (Cmd-K) starts in Neovim, which resumes
  # its last session (nvim/editing.nix).
  xdg.configFile."sesh/sesh.toml".text = ''
    [default_session]
    startup_command = "nvim"
  '';

  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;
    enableFishIntegration = false;
    settings = {
      command = "${pkgs.fish}/bin/fish --login -c 'exec ${tmux} -u new-session -A -s main'";
      shell-integration = "none";
      font-family = "FiraCode Nerd Font Mono";
      font-size = 13.5;
      font-feature = [
        "calt"
        "liga"
        "ss01"
        "ss03"
      ];
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
      window-padding-x = 4;
      window-padding-y = 0;
      window-padding-balance = true;
      window-padding-color = "extend-always"; # Extends lualine/tmux bars flush to window edges
      window-save-state = "never";
      # Fullscreen on the desktop instead of in its own Space: instant, and the
      # terminal runs beside the notch. Cmd-Enter leaves it for the window
      # below, the left half of the built-in display, uncovering Skim.
      fullscreen = "non-native";
      macos-non-native-fullscreen = true;
      window-width = 87;
      window-height = 57;
      window-position-x = 0;
      window-position-y = 0;
      macos-titlebar-style = "hidden";
      macos-icon = "custom-style";
      macos-icon-ghost-color = c.fg;
      macos-icon-screen-color = c.bg0;
      resize-overlay = "never";
      macos-option-as-alt = true;
      mouse-hide-while-typing = true;
      auto-update = "off";
      app-notifications = "no-clipboard-copy";
      confirm-close-surface = false;
      keybind = [
        (toTmux "super+t" "c")
        (toTmux "super+d" "|")
        (toTmux "super+shift+d" "-")
        (toTmux "super+w" "x")
        (toTmux "super+shift+left_bracket" "p")
        (toTmux "super+shift+right_bracket" "n")
        (toTmux "super+k" "s")
        (toTmux "super+g" "g")
        (toTmux "super+j" "j")
        (toTmux "super+f" "f")
        (toTmux "super+up" "\\x1b[A")
        (toTmux "super+slash" "/")
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
    escapeTime = 0;
    historyLimit = 50000;
    baseIndex = 1;
    focusEvents = true;
    aggressiveResize = true;
    clock24 = true;
    extraConfig = ''
      # Attach before starting the shell: sudo's PAM-stage reattachment is too
      # late for Touch ID in the current background server. Reload HM's env too.
      # exec replaces the default-shell -c wrapper with the pane's fish.
      set -g default-command "exec ${reattach} -- ${pkgs.coreutils}/bin/env -u __HM_SESS_VARS_SOURCED ${pkgs.fish}/bin/fish"
      set -s extended-keys on
      set -s extended-keys-format csi-u
      set -as terminal-features ',xterm-ghostty:RGB:extkeys:usstyle:clipboard:sync:hyperlinks:focus:cstyle'
      set -g set-clipboard on
      set -g allow-passthrough on
      set -g detach-on-destroy off
      set -g renumber-windows on
      set -g display-time 1500
      set -g set-titles on
      set -g set-titles-string '#S · #W'
      setw -g monitor-activity on
      set -g visual-activity off
      set -g automatic-rename-format '#{?#{m/r:^(fish|nvim)$,#{pane_current_command}},#{?#{==:#{pane_current_path},${config.home.homeDirectory}},~,#{b:pane_current_path}},#{pane_current_command}}'
      # Neovim handles these itself, and a window with a single pane has nothing
      # to move to or resize: fish and fzf keep Ctrl-L, Ctrl-K, Ctrl-J and Alt-H.
      %hidden passthrough='#{||:#{@pane-is-vim},#{==:#{window_panes},1}}'
      bind -n C-h if -F "$passthrough" 'send-keys C-h' { if -F '#{pane_at_left}' "" 'select-pane -L' }
      bind -n C-j if -F "$passthrough" 'send-keys C-j' { if -F '#{pane_at_bottom}' "" 'select-pane -D' }
      bind -n C-k if -F "$passthrough" 'send-keys C-k' { if -F '#{pane_at_top}' "" 'select-pane -U' }
      bind -n C-l if -F "$passthrough" 'send-keys C-l' { if -F '#{pane_at_right}' "" 'select-pane -R' }
      bind -T copy-mode-vi C-h if -F '#{pane_at_left}' "" 'select-pane -L'
      bind -T copy-mode-vi C-j if -F '#{pane_at_bottom}' "" 'select-pane -D'
      bind -T copy-mode-vi C-k if -F '#{pane_at_top}' "" 'select-pane -U'
      bind -T copy-mode-vi C-l if -F '#{pane_at_right}' "" 'select-pane -R'
      bind -n M-h if -F "$passthrough" 'send-keys M-h' 'resize-pane -L 3'
      bind -n M-j if -F "$passthrough" 'send-keys M-j' 'resize-pane -D 3'
      bind -n M-k if -F "$passthrough" 'send-keys M-k' 'resize-pane -U 3'
      bind -n M-l if -F "$passthrough" 'send-keys M-l' 'resize-pane -R 3'
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
      # fish marks prompts with OSC 133; vi copy mode has no default key for them.
      bind -T copy-mode-vi [ send -X previous-prompt
      bind -T copy-mode-vi ] send -X next-prompt
      bind s display-popup -E -w 60% -h 50% \
        "set -l target (sesh list --icons | fzf --ansi --no-sort --prompt '  ' --height 100%); if test -n \"\$target\"; sesh connect \"\$target\"; end"
      # Cmd-W, Cmd-G and Cmd-F act on what is in front: on Neovim through its
      # Alt-w/g/f maps when it is the pane, on tmux otherwise. An idle shell
      # closes without the question.
      bind x if -F '#{@pane-is-vim}' 'send-keys M-w' {
        if -F '#{==:#{pane_current_command},fish}' kill-pane { confirm-before -p 'kill-pane #P? (y/n)' kill-pane }
      }
      bind g if -F '#{@pane-is-vim}' 'send-keys M-g' {
        display-popup -E -w 90% -h 85% -d '#{pane_current_path}' lazygit
      }
      bind f if -F '#{@pane-is-vim}' 'send-keys M-f' {
        copy-mode
        command-prompt -i -T search -p 'search' { send -X search-backward-incremental '%%' }
      }
      bind Up copy-mode \; send -X previous-prompt
      # Cmd-J: one shell pane under the editor per window, in @drawer. Hiding
      # it zooms the pane above; it keeps running.
      bind j if -F '#{m:*1*,#{P:#{==:#{pane_id},#{@drawer}}}}' {
        if -F '#{window_zoomed_flag}' {
          run -C 'select-pane -t #{@drawer}'
        } {
          if -F '#{==:#{pane_id},#{@drawer}}' last-pane
          resize-pane -Z
        }
      } {
        split-window -v -l 30% -c '#{pane_current_path}'
        set -wF @drawer '#{pane_id}'
      }
      bind / display-popup -E -w 90 -h 90% -T ' keys ' '${keys}/bin/keys'
      set -g status-position top
      set -g status on
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
      # fill: the prompt takes the whole line instead of sitting on top of the bar.
      set -g message-style 'bg=${c.bg1},fg=${c.fg},fill=${c.bg1}'
      set -g message-command-style 'bg=${c.bg1},fg=${c.fg},fill=${c.bg1}'
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
      # HM's plugin list loads with a blocking run-shell; fingers binds ~90
      # keys one tmux call at a time, so load it in the background instead.
      set -g @fingers-key F
      set -g @fingers-hint-style 'fg=red,bold'
      set -g @fingers-highlight-style 'fg=yellow'
      set -g @fingers-selected-hint-style 'fg=green,bold'
      set -g @fingers-selected-highlight-style 'fg=green'
      set -g @fingers-backdrop-style 'fg=colour8'
      run-shell -b ${pkgs.tmuxPlugins.fingers.rtp}
    '';
  };
}
