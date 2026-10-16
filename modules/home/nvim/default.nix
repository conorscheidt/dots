{inputs, ...}: {
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./cp.nix
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };
}
