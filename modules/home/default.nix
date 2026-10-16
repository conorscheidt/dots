{
  imports = [
    ./shell.nix
    ./git.nix
    ./terminal.nix
    ./dev.nix
    ./apps.nix
    ./zathura.nix
    ./ai.nix
    ./nvim
  ];

  home = {
    username = "conor";
    homeDirectory = "/Users/conor";
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
