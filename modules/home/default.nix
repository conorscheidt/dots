{ pkgs, ... }: {
  imports = [
    ./shell.nix
    ./git.nix
    ./terminal.nix
  ];

  home = {
    stateVersion = "26.05";
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less -FRX";
      # Agents and scripts read man pages through pipes, where nvim would wait.
      MANPAGER = toString (
        pkgs.writeShellScript "manpager" ''
          if [ -t 1 ]; then exec nvim +Man!; else exec col -bx; fi
        ''
      );
    };
  };

  # Menu-bar items live in the per-host domain. nix-darwin's typed controlcenter
  # options write it without the host UUID and only as 18 or 24.
  targets.darwin.currentHostDefaults."com.apple.controlcenter" = {
    AirDrop = 24;
    BatteryShowPercentage = true;
    Bluetooth = 24;
    Display = 24;
    FocusModes = 2;
    NowPlaying = 24;
    Sound = 18;
    VoiceControl = 8;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = false;
    envExtra = "export SHELL_SESSIONS_DISABLE=1";
  };

  xdg.enable = true;
}
