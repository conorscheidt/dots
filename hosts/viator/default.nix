{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.determinate.darwinModules.default
    inputs.nix-homebrew.darwinModules.nix-homebrew
    inputs.home-manager.darwinModules.home-manager
    ../../modules/darwin/nix.nix
    ../../modules/darwin/system.nix
    ../../modules/darwin/apps.nix
    ../../modules/darwin/t3code.nix
  ];

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfree = true;
    # Overlays reuse this nixpkgs instead of evaluating each flake's own.
    overlays = [
      inputs.spotx-nix.overlays.default
      inputs.fenix.overlays.default
      (import ../../pkgs)
    ];
  };

  networking.hostName = "viator";

  system = {
    primaryUser = "conor";
    stateVersion = 6;
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
  };

  users.users.conor = {
    home = "/Users/conor";
    shell = pkgs.fish;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs; };
    users.conor = ../../modules/home;
  };
}
