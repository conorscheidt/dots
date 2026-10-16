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
  # nixpkgs trails Anthropic's release channel by days, and new models need the
  # newer CLI (T3 Code runs it). The entry is darwin-arm64 from
  # downloads.claude.ai/claude-code-releases/<version>/manifest.zst.json.
  claude-code =
    (final.lib.warnIf (final.lib.versionAtLeast prev.claude-code.version "2.1.325")
      "claude-code: nixpkgs has ${prev.claude-code.version}; drop the manifest override in pkgs/default.nix"
      (
        prev.claude-code.override {
          manifest = {
            version = "2.1.325";
            platforms.darwin-arm64 = {
              binary = "claude.zst";
              checksum = "5117df01bb8150ced024d8944a9706034e0c9bf6e28ee527b8d7735397aca6db";
            };
          };
        }
      )
    ).overrideAttrs
      (old: {
        # nixpkgs trusts only the keychain, which lacks the system roots, and
        # falls back on NIX_SSL_CERT_FILE; an app launched by launchd (T3 Code)
        # has no such variable and fails every TLS handshake. Unlike the
        # manifest, this stays when nixpkgs catches up.
        postFixup = (old.postFixup or "") + ''
          substituteInPlace $out/bin/claude \
            --replace-fail "CLAUDE_CODE_CERT_STORE-'system'" "CLAUDE_CODE_CERT_STORE-'bundled,system'"
        '';
      });
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
