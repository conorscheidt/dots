# SpotX owns Spotify's ad blocking and disables its self-updater. Keep the
# upstream-tested Spotify/patcher pair pinned together; update via the flake.
{
  inputs,
  pkgs,
  ...
}: {
  home.packages = [
    (inputs.spotx-nix.packages.${pkgs.stdenv.hostPlatform.system}.spotify-spotx.override {
      spotxArgs = ["--blockupdates"];
    })
  ];
}
