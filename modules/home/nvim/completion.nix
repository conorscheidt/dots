# blink.cmp with its native fuzzy matcher (built by nixpkgs), LazyVim's keys
# and friendly-snippets expanded by vim.snippet. Tab only ever jumps through
# snippets; nothing is inserted that you did not select.
{config, ...}: let
  lua = config.lib.nixvim.mkRaw;
in {
  programs.nixvim = {
    plugins.friendly-snippets.enable = true;

    plugins.blink-cmp = {
      enable = true;
      # blink's own plugin/ script registers its capabilities through
      # vim.lsp.config("*"); this option only feeds the legacy plugins.lsp.
      setupLspCapabilities = false;
      # Loading before the first buffer is read keeps its capabilities ahead
      # of every language server start (servers start on FileType).
      lazyLoad.settings.event = ["BufReadPre" "BufNewFile" "InsertEnter" "CmdlineEnter"];
      settings = {
        keymap = {
          preset = "enter";
          "<C-y>" = ["select_and_accept"];
          "<C-n>" = ["select_next" "fallback"];
          "<C-p>" = ["select_prev" "fallback"];
          "<Tab>" = ["snippet_forward" "fallback"];
          "<S-Tab>" = ["snippet_backward" "fallback"];
        };
        appearance.nerd_font_variant = "mono";
        snippets.preset = "default";
        completion = {
          accept.auto_brackets.enabled = true;
          list.selection = {
            preselect = true;
            auto_insert = false;
          };
          menu = {
            border = "rounded";
            draw = {
              treesitter = ["lsp"];
              columns = [
                {__unkeyed-1 = "kind_icon";}
                {
                  __unkeyed-1 = "label";
                  __unkeyed-2 = "label_description";
                  gap = 1;
                }
                {
                  __unkeyed-1 = "kind";
                  gap = 1;
                }
              ];
            };
          };
          documentation = {
            auto_show = true;
            auto_show_delay_ms = 100;
            window = {
              border = "rounded";
              max_width = 90;
              max_height = 25;
            };
          };
          ghost_text.enabled = false;
        };
        signature = {
          enabled = true;
          window = {
            border = "rounded";
            show_documentation = true;
          };
        };
        sources = {
          default = ["lsp" "path" "snippets" "buffer"];
          per_filetype.lua = lua ''{ inherit_defaults = true, "lazydev" }'';
          providers.lazydev = {
            name = "LazyDev";
            module = "lazydev.integrations.blink";
            score_offset = 100;
          };
        };
        cmdline = {
          enabled = true;
          keymap = {
            preset = "cmdline";
            "<Right>" = false;
            "<Left>" = false;
          };
          completion = {
            list.selection.preselect = false;
            menu.auto_show = lua ''function() return vim.fn.getcmdtype() == ":" end'';
            ghost_text.enabled = false;
          };
        };
        fuzzy = {
          implementation = "prefer_rust_with_warning";
          prebuilt_binaries.download = false;
          sorts = ["exact" "score" "sort_text"];
        };
      };
    };
  };
}
