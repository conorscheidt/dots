# Format on save through conform. Formatter binaries are PATH fallbacks, so a project's own
# toolchain (rustfmt from its rust-toolchain, biome from node_modules) wins.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.lib.nixvim) mkRaw;

  web = mkRaw "function(buf) return require('core').web_formatters(buf) end";
  webFiletypes = [
    "javascript"
    "javascriptreact"
    "typescript"
    "typescriptreact"
    "astro"
    "json"
    "jsonc"
    "json5"
    "css"
    "scss"
    "less"
    "html"
    "graphql"
    "handlebars"
    "markdown"
    "yaml"
  ];

  # Only the formatter: no fallback clangd on project PATHs, and none of
  # clang-tools' Python bindings (~100 MiB).
  clang-format = pkgs.runCommand "clang-format-${pkgs.llvmPackages.clang-unwrapped.version}" { } ''
    mkdir -p "$out/bin"
    ln -s ${pkgs.llvmPackages.clang-unwrapped}/bin/clang-format "$out/bin/clang-format"
  '';
in
{
  programs.nixvim = {
    plugins.conform-nvim = {
      enable = true;
      settings = {
        default_format_opts = {
          timeout_ms = 3000;
          async = false;
          quiet = false;
          lsp_format = "fallback";
        };
        # vim.b.autoformat overrides vim.g.autoformat (both default to on).
        format_on_save = mkRaw ''
          function(buf)
            local enabled = vim.b[buf].autoformat
            if enabled == nil then enabled = vim.g.autoformat ~= false end
            -- Badness and rustfmt refuse half-typed code (exit 1); that is
            -- normal mid-edit, and the compiler or rust-analyzer reports it.
            if enabled then return { quiet = vim.tbl_contains({ "tex", "plaintex", "bib", "rust" }, vim.bo[buf].filetype) } end
          end
        '';
        formatters_by_ft =
          lib.genAttrs webFiletypes (_: web)
          // {
            nix = [ "nixfmt" ];
            lua = [ "stylua" ];
            rust = [ "rustfmt" ];
            toml = [ "tombi" ];
            python = [
              "ruff_fix"
              "ruff_format"
            ];
            sh = [ "shfmt" ];
            bash = [ "shfmt" ];
            zsh = [ "shfmt" ];
            fish = [ "fish_indent" ];
          }
          # clangd's built-in clang-format is ~1 ms against ~45 ms for the
          # process; the binary is for sessions without clangd (nvt).
          // lib.genAttrs [ "c" "cpp" "objc" "objcpp" "cuda" ] (_: {
            __unkeyed-1 = "clang-format";
            lsp_format = "prefer";
          });
        formatters = {
          ruff_fix.append_args = [
            "--extend-select"
            "I"
          ];
          oxfmt.require_cwd = true;
          "biome-check".require_cwd = true;
          # Run the project's Prettier so its plugins and version apply.
          prettier.command = mkRaw ''
            function(_, ctx) return require("core").node_bin(ctx.filename, "prettier") or "prettier" end
          '';
          injected.options.ignore_errors = true;
        };
      };
      lazyLoad.settings = {
        event = "BufWritePre";
        cmd = "ConformInfo";
        keys = [
          {
            __unkeyed-1 = "<leader>cf";
            __unkeyed-2 = mkRaw ''function() require("conform").format() end'';
            mode = [
              "n"
              "x"
            ];
            desc = "Format";
          }
          {
            __unkeyed-1 = "<leader>cF";
            __unkeyed-2 = mkRaw ''function() require("conform").format({ formatters = { "injected" }, timeout_ms = 3000 }) end'';
            mode = [
              "n"
              "x"
            ];
            desc = "Format Injected Langs";
          }
        ];
      };
    };

    extraPackagesAfter = with pkgs; [
      nixfmt
      stylua
      shfmt
      clang-format
      oxfmt
      ripgrep
      fd
    ];
  };
}
