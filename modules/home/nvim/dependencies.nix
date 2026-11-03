# Manifest versions, features and upgrades through the detected manager command.
{
  config,
  pkgs,
  ...
}:
let
  inherit (config.lib.nixvim) mkRaw;
in
{
  programs.nixvim = {
    plugins.crates = {
      enable = true;
      settings = {
        completion.crates.enabled = true;
        lsp = {
          enabled = true;
          actions = true;
          completion = true;
          hover = true;
        };
        popup.autofocus = true;
      };
      # Load before reading so replay does not attach the in-process LSP twice.
      lazyLoad.settings.event = [
        "BufReadPre Cargo.toml"
        "BufNewFile Cargo.toml"
      ];
    };

    plugins.package-info = {
      enable = true;
      settings = {
        hide_up_to_date = true;
        hide_unstable_versions = false;
      };
      lazyLoad.settings.event = [
        "BufReadPre package.json"
        "BufNewFile package.json"
      ];
    };

    extraPackagesAfter = [ pkgs.npm-check-updates ];
    extraFiles."lua/dependencies.lua".source = ./lua/dependencies.lua;
    plugins.which-key.settings.spec = [
      {
        __unkeyed-1 = "<leader>p";
        group = "packages";
      }
    ];
    autoCmd = [
      {
        event = "FileType";
        pattern = [
          "json"
          "toml"
        ];
        group = "core";
        desc = "Manifest-local dependency actions";
        callback = mkRaw ''function(ev) require("dependencies").attach(ev.buf) end'';
      }
    ];
  };
}
