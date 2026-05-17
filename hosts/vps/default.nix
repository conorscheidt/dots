{ pkgs, lib, ... }:
{
  system.stateVersion = "25.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "mitigations=auto"
    "preempt=full"
    "threadirqs"
    "nohz=on"
    "ipv6.disable=0"
  ];

  boot.kernel.sysctl = {
    "kernel.pid_max" = 4194304;
    "kernel.threads-max" = 2097152;

    "fs.file-max" = 2097152;
    "fs.inotify.max_user_watches" = 1048576;
    "fs.inotify.max_user_instances" = 8192;

    "vm.swappiness" = 1;
    "vm.max_map_count" = 1048576;
    "vm.dirty_background_ratio" = 3;
    "vm.dirty_ratio" = 12;

    "net.core.somaxconn" = 65535;
    "net.core.netdev_max_backlog" = 32768;
    "net.core.rmem_max" = 67108864;
    "net.core.wmem_max" = 67108864;
    "net.ipv4.tcp_max_syn_backlog" = 16384;
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_fin_timeout" = 15;
    "net.ipv4.tcp_keepalive_time" = 300;
    "net.ipv4.tcp_keepalive_intvl" = 30;
    "net.ipv4.tcp_keepalive_probes" = 5;
    "net.ipv4.tcp_mtu_probing" = 1;
    "net.ipv4.tcp_rmem" = "4096 131072 67108864";
    "net.ipv4.tcp_wmem" = "4096 131072 67108864";
    "net.ipv4.ip_local_port_range" = "1024 65535";
    "net.ipv4.tcp_slow_start_after_idle" = 0;
    "net.ipv4.tcp_tw_reuse" = 1;
  };

  networking = {
    hostName = "basalt-vps";
    nftables.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
      allowPing = false;
      logRefusedConnections = false;
    };
  };

  time.timeZone = "UTC";

  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      MaxAuthTries = 3;
      AllowTcpForwarding = "no";
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
    };
    openFirewall = false;
  };

  services.fail2ban.enable = true;

  services.journald.extraConfig = ''
    SystemMaxUse=1G
    RuntimeMaxUse=256M
    MaxRetentionSec=14day
  '';

  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  users.users.deploy = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      # Replace with your real key before deploy.
      "ssh-ed25519 REPLACE_ME"
    ];
  };

  security = {
    sudo.wheelNeedsPassword = false;
    rtkit.enable = true;
  };

  security.pam.loginLimits = [
    { domain = "*"; type = "soft"; item = "nofile"; value = "1048576"; }
    { domain = "*"; type = "hard"; item = "nofile"; value = "1048576"; }
    { domain = "*"; type = "soft"; item = "nproc"; value = "524288"; }
    { domain = "*"; type = "hard"; item = "nproc"; value = "524288"; }
  ];

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      max-jobs = "auto";
      cores = 0;
      accept-flake-config = true;
      trusted-users = [ "root" "deploy" ];
    };

    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };

    optimise.automatic = true;
  };

  environment = {
    systemPackages = with pkgs; [
      git
      curl
      wget
      htop
      jq
      ripgrep
      tmux
    ];

    variables = {
      EDITOR = "nvim";
    };
  };

  # Placeholder basalt unit for later wiring to your monolith checkout.
  systemd.services.basalt = {
    description = "Basalt monolith";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      User = "deploy";
      Group = "users";
      WorkingDirectory = "/home/deploy/dev/basalt";
      Restart = "always";
      RestartSec = 1;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [ "/home/deploy/dev/basalt" "/var/lib/basalt" ];
      LimitNOFILE = 1048576;
      LimitNPROC = 524288;
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      ExecStart = "${pkgs.bash}/bin/bash -lc 'echo wire basalt start command here; sleep infinity'";
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/basalt 0750 deploy users - -"
    "d /home/deploy/dev 0755 deploy users - -"
  ];
}
