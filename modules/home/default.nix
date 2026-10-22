{osConfig, ...}: let
  username = osConfig.system.primaryUser;
in {
  imports = [
    ./shell.nix
    ./git.nix
    ./terminal.nix
    ./dev.nix
    ./apps.nix
    ./spotify.nix
    ./brave.nix
    ./zathura.nix
    ./ai.nix
    ./nvim
  ];

  home = {
    inherit username;
    homeDirectory = osConfig.users.users.${username}.home;
    stateVersion = "26.05";
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less -FRX";
      MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    };
  };

  xdg.enable = true;
}
