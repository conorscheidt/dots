# Homebrew is only a cask installer for apps nixpkgs cannot provide well:
# Brave (same-day Chromium security updates via its own updater), the
# Claude and ChatGPT/Codex desktop apps, NordVPN (system extension) and Teams
# (root .pkg installer). No formulae. Everything else comes from Nix;
# Amphetamine stays with the App Store; Muse and Raycast Beta update themselves.
{
  nix-homebrew = {
    enable = true;
    user = "conor";
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
