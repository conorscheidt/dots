{
  lib,
  pkgs,
  ...
}:
let
  extensionIds = [
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

  localState = {
    # Experimental flags require a measured benefit before being pinned here.
    browser.enabled_labs_experiments = [ ];
    dns_over_https = {
      mode = "secure";
      templates = "https://chrome.cloudflare-dns.com/dns-query";
    };
    brave = {
      p3a.enabled = false;
      stats.reporting_enabled = false;
    };
    user_experience_metrics.reporting_enabled = false;
    performance_tuning.high_efficiency_mode = {
      state = 2;
      aggressiveness = 0;
    };
  };

  preferences = {
    extensions.pinned_extensions = [
      "pejdijmoenmkgeppbflobdenhhabjlaj" # iCloud Passwords
      "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
      "hhfnghjdeddcfegfekjeihfmbjenlomm" # Web Activity Time Tracker
      "ihienfbdfdamhmhhiokjnjmpjgbenedg" # Canvas Refined
    ];
    net.network_prediction_options = 3;
    webrtc.ip_handling_policy = "disable_non_proxied_udp";
    brave = {
      tabs = {
        vertical_tabs_enabled = true;
        vertical_tabs_collapsed = true;
        vertical_tabs_floating_enabled = true;
        vertical_tabs_expanded_state_per_window = false;
        vertical_tabs_hide_completely_when_collapsed = false;
        vertical_tabs_show_title_on_window = false;
        tree_tabs_enabled = true;
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
        tab_organization_enabled = false;
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
    [ -f "$dir/Local State" ] && [ -f "$dir/Default/Preferences" ] || exit 0
    if /usr/bin/pgrep -xq "Brave Browser"; then
      echo "brave-apply-config: Brave is running; profile settings skipped. Quit Brave and run brave-apply-config to apply them." >&2
      exit 0
    fi
    tmp=""
    trap 'if [ -n "$tmp" ]; then rm -f "$tmp"; fi' EXIT
    merge() {
      tmp=$(mktemp "$1.XXXXXX")
      ${jq} -c --argjson p "$2" '
        . as $current | . * $p
        | if ($p.extensions.pinned_extensions? | type) == "array" then
            .extensions.pinned_extensions = reduce
              ($p.extensions.pinned_extensions + ($current.extensions.pinned_extensions // []))[] as $id
              ([]; if index($id) == null then . + [$id] else . end)
          else . end
      ' "$1" > "$tmp"
      if cmp -s <(${jq} -S . "$1") <(${jq} -S . "$tmp"); then
        rm "$tmp"
      else
        [ -e "$1.pre-nix" ] || cp -p "$1" "$1.pre-nix"
        cp -p "$1" "$1.pre-nix-latest"
        mv "$tmp" "$1"
        echo "brave-apply-config: updated $(basename "$1")"
      fi
      tmp=""
    }
    merge "$dir/Local State" ${lib.escapeShellArg (builtins.toJSON localState)}
    merge "$dir/Default/Preferences" ${lib.escapeShellArg (builtins.toJSON preferences)}
  '';
in
{
  programs.brave = {
    enable = true;
    package = null; # The declarative cask owns the app and vendor updates.
    extensions = map (id: { inherit id; }) extensionIds;
  };

  # User defaults are recommended policy values, not managed device policy.
  # Only policies supporting recommendations can take effect here.
  targets.darwin.defaults."com.brave.Browser" = {
    BraveAIChatEnabled = false;
    BraveRewardsDisabled = true;
    BraveVPNDisabled = true;
    BraveWalletDisabled = true;
    TorDisabled = true;
    DnsOverHttpsMode = "secure";
    DnsOverHttpsTemplates = "https://chrome.cloudflare-dns.com/dns-query";
    QuicAllowed = true;
    # Leave NetworkPredictionOptions unset: its policy enum has no Extended
    # value. The profile's net.network_prediction_options = 3 selects it.
    MetricsReportingEnabled = false;
    HighEfficiencyModeEnabled = true;
  };

  home.packages = [ apply ];

  # Import these files through each extension's settings UI.
  xdg.configFile."brave/extension-settings".source = ./brave-settings;

  home.activation.braveConfig = lib.hm.dag.entryAfter [ "writeBoundary" "setDarwinDefaults" ] ''
    # Removing declarations does not delete already-imported defaults keys.
    # Extensions are installed through Home Manager's External Extensions files;
    # ExtensionInstallForcelist requires mandatory policy, unavailable here.
    for key in NetworkPredictionOptions ExtensionInstallForcelist; do
      if /usr/bin/defaults read com.brave.Browser "$key" >/dev/null 2>&1; then
        run /usr/bin/defaults delete com.brave.Browser "$key"
      fi
    done
    run ${apply}/bin/brave-apply-config
  '';

  home.file."web-ext.config.ts".text = ''
    export default {
      binaries: { chrome: "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" },
      chromiumArgs: ["--user-data-dir=./.wxt/brave-data", "--no-first-run", "--no-default-browser-check"],
    };
  '';
}
