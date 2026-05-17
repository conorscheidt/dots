{pkgs, ...}: {
  system.stateVersion = "26.05";

  ########################################
  # Boot & Hardware
  ########################################
  boot.loader.systemd-boot.enable = false;
  boot.initrd.availableKernelModules = ["virtio_pci" "virtio_scsi" "virtio_blk" "virtio_net"];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "quiet"
    "loglevel=3"
    "nowatchdog"
    "nmi_watchdog=0"
  ];

  boot.loader.grub.enable = true;

  disko.devices = {
    disk = {
      main = {
        device = "/dev/sda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # For GRUB MBR
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = ["noatime" "nodiratime"];
              };
            };
          };
        };
      };
    };
  };

  ########################################
  # Kernel Tuning
  ########################################
  boot.kernel.sysctl = {
    # 8GB RAM tuning: Limit PIDs/threads to avoid kernel memory exhaustion (task_struct overhead)
    "kernel.pid_max" = 128 * 1024;
    "kernel.threads-max" = 128 * 1024;
    # 1M max files -> ~1GB RAM for file descriptors, perfectly safe for 8GB RAM
    "fs.file-max" = 1048576;
    "fs.inotify.max_user_watches" = 512 * 1024;
    "fs.inotify.max_user_instances" = 8 * 1024;
    # zRAM optimization (matches 50% memoryPercent and zstd)
    "vm.swappiness" = 80;
    "vm.max_map_count" = 1024 * 1024;
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 15;
    # Network tuning
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.somaxconn" = 65535;
    "net.core.netdev_max_backlog" = 16 * 1024;
    # 16MB max buffer per socket to handle bursts without OOMing on 8GB RAM
    "net.core.rmem_max" = 16 * 1024 * 1024;
    "net.core.wmem_max" = 16 * 1024 * 1024;
    "net.ipv4.tcp_max_syn_backlog" = 8 * 1024;
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_fin_timeout" = 15;
    "net.ipv4.tcp_keepalive_time" = 300;
    "net.ipv4.tcp_keepalive_intvl" = 30;
    "net.ipv4.tcp_keepalive_probes" = 5;
    "net.ipv4.tcp_mtu_probing" = 1;
    # Min, Default, Max (16MB)
    "net.ipv4.tcp_rmem" = "4096 ${toString (128 * 1024)} ${toString (16 * 1024 * 1024)}";
    "net.ipv4.tcp_wmem" = "4096 ${toString (128 * 1024)} ${toString (16 * 1024 * 1024)}";
    "net.ipv4.ip_local_port_range" = "1024 65535";
    "net.ipv4.tcp_slow_start_after_idle" = 0;
    "net.ipv4.tcp_tw_reuse" = 1;
    "net.ipv4.tcp_notsent_lowat" = 16 * 1024;
  };

  ########################################
  # Networking & Cloud-Init
  ########################################
  networking = {
    hostName = "vps";
    useDHCP = false;
    nftables.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [22 80 443];
      # TODO: Add specific TCP/UDP ports required by your Basalt node (e.g., P2P and RPC)
      allowPing = true;
      logRefusedConnections = false;
    };
  };

  systemd.network = {
    enable = true;
    networks."10-internet" = {
      # TODO: Insert your VPS's actual MAC address below
      matchConfig.MACAddress = "00:50:56:5e:bd:0d";
      linkConfig.RequiredForOnline = "routable";

      address = [
        "212.56.45.37/24"
        "2605:a140:2294:8506::1/64" # Simplified IPv6 notation
      ];
      routes = [
        {
          Gateway = "212.56.45.1"; # Standard Contabo IPv4 gateway
          GatewayOnLink = true;
        }
        {
          Gateway = "fe80::1";
          GatewayOnLink = true;
        }
      ];
      dns = [
        "1.1.1.1" # Cloudflare IPv4
        "1.0.0.1" # Cloudflare IPv4 (Fallback)
        "2606:4700:4700::1111" # Cloudflare IPv6
        "2606:4700:4700::1001" # Cloudflare IPv6 (Fallback)
      ];
    };
  };

  services.cloud-init = {
    enable = true;
    network.enable = false; # Let systemd.network handle interfaces
  };

  ########################################
  # System Configuration
  ########################################
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  powerManagement.cpuFreqGovernor = "performance";
  services.qemuGuest.enable = true;
  services.fstrim.enable = true;

  ########################################
  # Services (SSH, Fail2ban, Journald, zRAM)
  ########################################
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
      X11Forwarding = false;
      UseDns = false;
      MaxAuthTries = 3;
      AllowTcpForwarding = "no";
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
    };
  };
  services.fail2ban.enable = true;
  services.journald.extraConfig = ''
    SystemMaxUse=512M
    RuntimeMaxUse=128M
    MaxRetentionSec=14day
  '';
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  ########################################
  # Users & Security
  ########################################
  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOvr03CG6CBuxMW8lSXJUc2Niq1FNEPR9BQoBhWE9sUj conor@crsche.com"
    ];
  };
  users.users.deploy = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOvr03CG6CBuxMW8lSXJUc2Niq1FNEPR9BQoBhWE9sUj conor@crsche.com"
    ];
  };
  security.sudo.wheelNeedsPassword = false;
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "1048576";
    }
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = "1048576";
    }
    {
      domain = "*";
      type = "soft";
      item = "nproc";
      value = toString (128 * 1024);
    }
    {
      domain = "*";
      type = "hard";
      item = "nproc";
      value = toString (128 * 1024);
    }
  ];

  ########################################
  # Nix Settings
  ########################################
  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
      # 4 CPU cores available. Limiting max-jobs ensures we don't OOM during nixos-rebuild
      max-jobs = 4;
      cores = 0;
      trusted-users = ["root" "deploy"];
      system-features = [
        "benchmark"
        "big-parallel"
        "kvm"
        "nixos-test"
        "uid-range"
        "gccarch-znver1"
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  ########################################
  # Packages & Environment
  ########################################
  programs.mosh.enable = true;
  environment = {
    systemPackages = with pkgs; [
      # git
      # curl
      # htop
      # jq
      # ripgrep
      # tmux
    ];
    variables.EDITOR = "nvim";
  };
}
