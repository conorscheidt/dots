# Brave is installed by its Homebrew cask (it updates itself). Nix declares
# everything else: the extensions (installed via External Extensions
# manifests), the brave://flags set, and the profile settings below. Flags and
# settings live in Brave's own JSON files, so they are merged in only while
# Brave is quit (activation, or `brave-apply-config` afterwards), and only
# untracked prefs are touched so Brave's integrity checks never reset them.
# Extension *settings* cannot be declared (none of these support managed
# storage); Brave Sync is the way to carry them across machines.
{
  lib,
  pkgs,
  ...
}: let
  flags = [
    # Latency: preloading, prerendering, prefetch, prewarm, network.
    "default-search-engine-prewarm@1"
    "dse-preload2@1"
    "dse-preload2-on-press@1"
    "omnibox-search-client-prefetch@1"
    "omnibox-zero-suggest-prefetching-on-web@1"
    "omnibox-zero-suggest-prefetching-for-composebox@1"
    "prerender2@1"
    "prerender2-cross-origin-iframes@1"
    "enable-tls13-early-data@1"
    "happy-eyeballs-v3@1"
    "enable-quic@1"
    "enable-zero-copy@1"
    "enable-parallel-downloading@1"
    "renderer-side-content-decoding@1"
    "document-patching@1"
    "trees-in-viz@1"
    "enable-resampling-scroll-events-experimental-prediction@1"
    "pdf-use-skia-renderer@1"
    # Leo, Rewards and Wallet features off.
    "brave-ai-chat@2"
    "brave-ai-chat-history@2"
    "brave-ai-chat-context-menu-rewrite-in-place@2"
    "brave-ai-chat-open-leo-from-brave-search@2"
    "brave-ai-chat-rich-search-widgets@2"
    "brave-ai-chat-show-input-on-new-tab-page@2"
    "brave-ai-chat-tab-management-tool@2"
    "brave-ai-chat-web-content-association-default@2"
    "brave-ai-host-specific-distillation@2"
    "brave-rewards-allow-self-custody-providers@2"
    "brave-rewards-platform-creator-detection@2"
    "brave-wallet-bitcoin@2"
    "brave-wallet-cardano@2"
    # Interface and tooling.
    "brave-adblock-experimental-list-default@1"
    "brave-focus-mode@5"
    "brave-omnibox-tab-switch-by-default@1"
    "brave-request-otr-tab@1"
    "brave-shields-page-info@1"
    "brave-show-strict-fingerprinting-mode@1"
    "brave-shred@1"
    "brave-vertical-tab-expand-delay@5"
    "browser-initiated-automatic-picture-in-picture@1"
    "chrome-dark-neutrals-26@1"
    "credential-management-unified-ui@1"
    "dark-mode-surface-tokens@1"
    "devtools-enable-durable-messages@1"
    "devtools-protocol-monitor@1"
    "enable-input-protection@1"
    "enable-psst@1"
    "extensions-menu-access-control@1"
    "passkey-unlock-error-ui@1"
    "playlist@1"
    "read-anything-line-focus@1"
    "search-settings-update@1"
    "side-panel-flyover-animation@1"
    "tab-group-ribbon@1"
    "tab-strip-declutter@1"
    "toolbar-glow-up@1"
  ];

  localState = {
    browser.enabled_labs_experiments = flags;
    dns_over_https = {
      mode = "secure";
      templates = "https://chrome.cloudflare-dns.com/dns-query";
    };
    brave = {
      p3a.enabled = false;
      stats.reporting_enabled = false;
    };
    user_experience_metrics.reporting_enabled = false;
    # Memory Saver on, but only discards tabs under real memory pressure.
    performance_tuning.high_efficiency_mode = {
      state = 2;
      aggressiveness = 0;
    };
  };

  preferences = {
    net.network_prediction_options = 3; # Extended preloading
    webrtc.ip_handling_policy = "disable_non_proxied_udp";
    brave = {
      tabs = {
        vertical_tabs_enabled = true;
        vertical_tabs_collapsed = true;
        vertical_tabs_floating_enabled = true;
        vertical_tabs_expanded_state_per_window = false;
        vertical_tabs_show_title_on_window = false;
        tree_tabs_enabled = false;
        hover_mode = 2;
        always_use_mini_accent_icon = true;
        mute_indicator_not_clickable = true;
      };
      new_tab_page = {
        show_brave_news = false;
        show_brave_vpn = false;
        show_rewards = false;
        show_together = false;
        show_clock = true;
      };
      news.opted_in = false;
      ai_chat = {
        show_toolbar_button = false;
        context_menu_enabled = false;
        autocomplete_provider_enabled = false;
      };
      rewards.show_brave_rewards_button_in_location_bar = false;
      wallet.show_wallet_icon_on_toolbar = false;
      brave_vpn.show_button = false;
      speedreader.enabled_for_all_sites = true;
      shields.advanced_view_enabled = true;
    };
  };

  jq = lib.getExe pkgs.jq;
  apply = pkgs.writeShellScriptBin "brave-apply-config" ''
    set -eu
    dir="$HOME/Library/Application Support/BraveSoftware/Brave-Browser"
    # A profile that does not exist yet is created by Brave on first launch.
    [ -f "$dir/Local State" ] && [ -f "$dir/Default/Preferences" ] || exit 0
    if /usr/bin/pgrep -xq "Brave Browser"; then
      echo "brave-apply-config: Brave is running; quit it and run brave-apply-config" >&2
      exit 0
    fi
    tmp=""
    trap 'if [ -n "$tmp" ]; then rm -f "$tmp"; fi' EXIT
    merge() { # file, JSON patch: deep-merge, write atomically only on change
      [ -e "$1.pre-nix" ] || cp -p "$1" "$1.pre-nix" # first run keeps the original
      tmp=$(mktemp "$1.XXXXXX")
      ${jq} -c --argjson p "$2" '. * $p' "$1" > "$tmp"
      if cmp -s <(${jq} -S . "$1") <(${jq} -S . "$tmp"); then
        rm "$tmp"
      else
        mv "$tmp" "$1" && echo "brave-apply-config: updated $(basename "$1")"
      fi
      tmp=""
    }
    merge "$dir/Local State" ${lib.escapeShellArg (builtins.toJSON localState)}
    merge "$dir/Default/Preferences" ${lib.escapeShellArg (builtins.toJSON preferences)}
  '';
in {
  programs.brave = {
    enable = true;
    package = null; # the cask owns the app
    extensions = map (id: {inherit id;}) [
      "pejdijmoenmkgeppbflobdenhhabjlaj" # iCloud Passwords
      "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
      "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock
      "gebbhagfogifgggkldgodflihgfeippi" # Return YouTube Dislike
      "ogkoifddpkoabehfemkolflcjhklmkge" # Tweaks for YouTube
      "ihienfbdfdamhmhhiokjnjmpjgbenedg" # Canvas Refined
      "aefkmifgmaafnojlojpnekbpbmjiiogg" # Popup Blocker (strict)
      "hhfnghjdeddcfegfekjeihfmbjenlomm" # Web Activity Time Tracker
      "eikknpnckalfaafkjkkjbikfbkbkdnfc" # Zelix
    ];
  };

  home.packages = [apply];
  home.activation.braveConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run ${apply}/bin/brave-apply-config
  '';

  # WXT/web-ext: launch Brave with a persistent per-project dev profile.
  home.file."web-ext.config.ts".text = ''
    export default {
      binaries: { chrome: "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" },
      chromiumArgs: ["--user-data-dir=./.wxt/brave-data", "--no-first-run", "--no-default-browser-check"],
    };
  '';
}
