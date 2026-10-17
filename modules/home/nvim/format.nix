# Format on save with one formatter per file (conform), and markdownlint
# through nvim-lint. Formatter binaries are PATH fallbacks, so a project's own
# toolchain (rustfmt from its rust-toolchain, biome from node_modules) wins.
{
  config,
  lib,
  pkgs,
  ...
}: let
  lua = config.lib.nixvim.mkRaw;

  web = lua "function(buf) return require('core').web_formatters(buf) end";
  webFiletypes = [
    "javascript"
    "javascriptreact"
    "typescript"
    "typescriptreact"
    "vue"
    "svelte"
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

  # Only clang-format: the rest of clang-tools would put a second clangd on
  # PATH (see core.clangd).
  clang-format = pkgs.runCommand "clang-format-${pkgs.clang-tools.version}" {} ''
    mkdir -p $out/bin
    ln -s ${pkgs.clang-tools}/bin/clang-format $out/bin/clang-format
  '';
in {
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
        format_on_save = lua ''
          function(buf)
            local enabled = vim.b[buf].autoformat
            if enabled == nil then enabled = vim.g.autoformat ~= false end
            if enabled then return {} end
          end
        '';
        formatters_by_ft =
          lib.genAttrs webFiletypes (_: web)
          // {
            nix = ["alejandra"];
            lua = ["stylua"];
            rust = ["rustfmt"];
            toml = ["taplo"];
            python = ["ruff_organize_imports" "ruff_format"];
            sh = ["shfmt"];
            bash = ["shfmt"];
            zsh = ["shfmt"];
            fish = ["fish_indent"];
            c = ["clang_format"];
            cpp = ["clang_format"];
            objc = ["clang_format"];
            objcpp = ["clang_format"];
            cuda = ["clang_format"];
          };
        formatters = {
          oxfmt.require_cwd = true;
          "biome-check".require_cwd = true;
          # Run the project's Prettier so its plugins and version apply.
          prettier.command = lua ''
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
            __unkeyed-2 = lua ''function() require("conform").format() end'';
            mode = ["n" "x"];
            desc = "Format";
          }
          {
            __unkeyed-1 = "<leader>cF";
            __unkeyed-2 = lua ''function() require("conform").format({ formatters = { "injected" }, timeout_ms = 3000 }) end'';
            mode = ["n" "x"];
            desc = "Format Injected Langs";
          }
        ];
      };
    };

    plugins.lint = {
      enable = true;
      lintersByFt.markdown = ["markdownlint-cli2"];
      autoCmd = {
        event = ["BufReadPost" "BufWritePost" "InsertLeave"];
        group = "core";
        # Scheduled because BufReadPost runs before filetype detection. MDX
        # shares the markdown filetype, but its JSX is not lintable Markdown.
        callback = lua ''
          function(ev)
            vim.schedule(function()
              if not vim.api.nvim_buf_is_valid(ev.buf) or vim.bo[ev.buf].buftype ~= "" then return end
              if vim.api.nvim_buf_get_name(ev.buf):match("%.mdx$") then return end
              vim.api.nvim_buf_call(ev.buf, function() require("lint").try_lint() end)
            end)
          end
        '';
      };
    };

    extraPackagesAfter = with pkgs; [
      alejandra
      stylua
      shfmt
      oxfmt
      markdownlint-cli2
      clang-format
      ripgrep
      fd
    ];
  };
}
