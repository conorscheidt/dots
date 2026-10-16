{ config, ... }: {
  nix-homebrew = {
    enable = true;
    user = config.system.primaryUser;
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;
    mutableTaps = false;
    taps = { };
    extraEnv.HOMEBREW_NO_ANALYTICS = "1";
  };

  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "uninstall";
      autoUpdate = false;
      upgrade = false;
    };
    casks = [
      "autodesk-fusion"
      "brave-browser"
      "chatgpt"
      "nordvpn"
      "slack"
      "t3-code@nightly"
    ];
    # With any entry here, cleanup also uninstalls every undeclared App Store app.
    masApps.Amphetamine = 937984704;
  };
}
