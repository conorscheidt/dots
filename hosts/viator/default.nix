{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.determinate.darwinModules.default
    inputs.nix-homebrew.darwinModules.nix-homebrew
    inputs.home-manager.darwinModules.home-manager
    ../../modules/darwin/nix.nix
    ../../modules/darwin/system.nix
    ../../modules/darwin/apps.nix
  ];

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfree = true;
  };

  networking.hostName = "viator";

  system = {
    primaryUser = "conor";
    stateVersion = 6;
  };

  users.users.conor = {
    home = "/Users/conor";
    shell = pkgs.fish;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {inherit inputs;};
    users.conor = ../../modules/home;
  };
}
