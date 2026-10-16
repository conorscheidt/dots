{
  config,
  inputs,
  lib,
  ...
}:
let
  user = config.system.primaryUser;
in
{
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
      # Bound concurrent builds and the parallelism requested from each builder.
      # Builders can exceed this; these settings are not a memory limit.
      max-jobs = 4;
      cores = 4;
      http-connections = 50;
      max-substitution-jobs = 32;
      download-buffer-size = 256 * 1024 * 1024;
      connect-timeout = 5;
      auto-optimise-store = true;
      warn-dirty = false;
      nix-path = "nixpkgs=flake:nixpkgs";
      flake-registry = lib.mkForce "https://install.determinate.systems/flake-registry/stable/flake-registry.json";
    };
    registry.nixpkgs.flake = inputs.nixpkgs;
    determinateNixd = {
      # The default, made explicit: nh-clean below relies on it to collect.
      garbageCollector.strategy = "automatic";
      # null turns crash reporting off; unset means Determinate's endpoint.
      telemetry.sentry.endpoint = null;
    };
  };

  programs.nh = {
    enable = true;
    flake = "${config.users.users.${user}.home}/dev/dots";
  };

  # programs.nh.clean requires nix.enable, which Determinate turns off. Prune
  # system and user generations as root; Determinate Nixd's automatic garbage
  # collector reclaims the store, so nh must not run a second collection.
  launchd.daemons.nh-clean = {
    # Determinate's nix, which matches the running daemon.
    path = [
      "/nix/var/nix/profiles/default/bin"
      "/usr/bin"
      "/bin"
    ];
    # --keep-one keeps every direnv root; only stale `result` links age out.
    command = "${lib.getExe config.programs.nh.package} clean all --keep 3 --keep-since 14d --keep-one --no-gc";
    serviceConfig = {
      StartCalendarInterval = [
        {
          Weekday = 7;
          Hour = 3;
          Minute = 15;
        }
      ];
      ProcessType = "Background";
      LowPriorityIO = true;
      LowPriorityBackgroundIO = true;
      StandardOutPath = "/var/log/nh-clean.log";
      StandardErrorPath = "/var/log/nh-clean.log";
    };
  };
}
