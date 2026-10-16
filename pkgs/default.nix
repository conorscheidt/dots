final: prev: {
  instant-space-switcher =
    final.lib.warnIf (final.lib.versionAtLeast prev.instant-space-switcher.version "3.1")
      "instant-space-switcher: nixpkgs has ${prev.instant-space-switcher.version}; drop the override in pkgs/default.nix"
      (
        prev.instant-space-switcher.overrideAttrs (
          finalAttrs: _: {
            version = "3.1";
            src = final.fetchurl {
              url = "https://github.com/jurplel/InstantSpaceSwitcher/releases/download/v${finalAttrs.version}/InstantSpaceSwitcher-${finalAttrs.version}.dmg";
              hash = "sha256-rsy241SZcA1Ot/cdfRKwrFnRtCfLMV8nW6HfA9nJ5eo=";
            };
          }
        )
      );
  # Spicetify supports macOS Spotify 1.3.9 from 2.46.7.
  spicetify-cli =
    final.lib.warnIf (final.lib.versionAtLeast prev.spicetify-cli.version "2.46.7")
      "spicetify-cli: nixpkgs has ${prev.spicetify-cli.version}; drop the override in pkgs/default.nix"
      (
        prev.spicetify-cli.overrideAttrs (
          finalAttrs: _: {
            version = "2.46.7";
            src = final.fetchFromGitHub {
              owner = "spicetify";
              repo = "cli";
              tag = "v${finalAttrs.version}";
              hash = "sha256-TO6YD22EvBG9QgkgVlXHxxLYpN42jcPPDlVSmrSd9RU=";
            };
            vendorHash = "sha256-F16qjdsdHbPMhdeTK1gDboLLwz729PzmNt0D6VsmFfU=";
          }
        )
      );
  # nixpkgs is at 1.7.9 (no macOS 26/27 fixes), and its fixupPhase strips and
  # ad-hoc re-signs the bundle, dropping Skim's Developer ID signature (which
  # keeps its Documents-folder grant stable). Keep the bundle as shipped.
  skimpdf =
    final.lib.warnIf (final.lib.versionAtLeast prev.skimpdf.version "1.7.19")
      "skimpdf: nixpkgs has ${prev.skimpdf.version}; drop the version bump in pkgs/default.nix (keep dontFixup)"
      (
        prev.skimpdf.overrideAttrs (
          finalAttrs: _: {
            version = "1.7.19";
            src = final.fetchurl {
              name = "Skim-${finalAttrs.version}.dmg";
              url = "mirror://sourceforge/project/skim-app/Skim/Skim-${finalAttrs.version}/Skim-${finalAttrs.version}.dmg";
              hash = "sha256-VZqt+GpgZhUX7VIyifD4HLToWczbtUGRzGTUvj13gdw=";
            };
            dontFixup = true;
          }
        )
      );
}
