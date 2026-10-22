# Casks cover self-updating apps and privileged installers; CLI tools use Nix.
{config, ...}: {
  nix-homebrew = {
    enable = true;
    user = config.system.primaryUser;
    # Casks are managed during activation; interactive shells use Nix tools.
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;
    # Casks and formulae install from the Homebrew API; no tap checkouts.
    mutableTaps = false;
    taps = {};
    extraEnv.HOMEBREW_NO_ANALYTICS = "1";
  };

  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "uninstall"; # anything not declared here is removed (app data is kept)
      autoUpdate = false;
      upgrade = false; # these casks update themselves
    };
    casks = [
      "brave-browser"
      "chatgpt"
      "claude"
      "microsoft-teams"
      "nordvpn"
    ];
  };
}
