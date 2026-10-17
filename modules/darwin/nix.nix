# Determinate owns the daemon. Its base nix.conf already enables flakes,
# lazy-trees, parallel evaluation (eval-cores = 0), max-jobs = auto, and
# determinate-nixd runs automatic garbage collection; only additions live here.
{
  inputs,
  lib,
  pkgs,
  ...
}: {
  determinateNix = {
    enable = true;
    customSettings = {
      extra-substituters = [
        "https://nix-community.cachix.org"
        "https://fenix.cachix.org"
      ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "fenix.cachix.org-1:ecJhr+RdYEdcVgUkjruiYhjbBloIEGov7bos90cZi0Q="
      ];
      # Lets project flakes' nixConfig caches apply without a prompt.
      trusted-users = ["root" "conor"];
      # Faster cold substitution; the 64 MiB default stalls on large NARs.
      http-connections = 50;
      max-substitution-jobs = 32;
      download-buffer-size = 268435456;
      connect-timeout = 5;
      auto-optimise-store = true;
      warn-dirty = false;
      # `<nixpkgs>` resolves through the pinned registry entry below instead of
      # Determinate's weekly FlakeHub tarball.
      nix-path = "nixpkgs=flake:nixpkgs";
      # Pinning a registry entry makes the module point flake-registry at the
      # local file; keep Determinate's global registry (templates#, etc.).
      flake-registry = lib.mkForce "https://install.determinate.systems/flake-registry/stable/flake-registry.json";
    };
    # `nix shell nixpkgs#foo` uses this flake's locked (already cached) nixpkgs.
    registry.nixpkgs.flake = inputs.nixpkgs;
  };

  # Prune old system/user generations weekly; determinate-nixd collects the
  # garbage they leave behind.
  launchd.daemons.nh-clean = {
    command = "${pkgs.nh}/bin/nh clean all --keep 3 --keep-since 14d --no-gcroots --no-gc --elevation-strategy none";
    serviceConfig = {
      StartCalendarInterval = [
        {
          Weekday = 1;
          Hour = 11;
          Minute = 0;
        }
      ];
      StandardErrorPath = "/var/log/nh-clean.log";
    };
  };
}
