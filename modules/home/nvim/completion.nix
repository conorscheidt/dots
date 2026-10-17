# blink.cmp with its native fuzzy matcher (built by nixpkgs), LazyVim's keys
# and friendly-snippets expanded by vim.snippet. Tab only ever jumps through
# snippets; nothing is inserted that you did not select.
{ config, ... }:
let
  inherit (config.lib.nixvim) mkRaw;
in
{
  programs.nixvim = {
    plugins.friendly-snippets.enable = true;

    plugins.blink-cmp = {
      enable = true;
      # blink's own plugin/ script registers its capabilities through
      # vim.lsp.config("*"); this option only feeds the legacy plugins.lsp.
      setupLspCapabilities = false;
      # Loading before the first buffer is read keeps its capabilities ahead
      # of every language server start (servers start on FileType).
      lazyLoad.settings.event = [
        "BufReadPre"
        "BufNewFile"
        "InsertEnter"
        "CmdlineEnter"
      ];
      settings = {
        keymap = {
          preset = "enter";
          "<C-y>" = [
            "select_and_accept"
            "fallback"
          ];
        };
        appearance.nerd_font_variant = "mono";
        completion = {
          list.selection = {
            # In TeX prose Enter stays a newline unless a \command or {argument}
            # menu (a trigger character) is open.
            preselect = mkRaw ''
              function(ctx)
                return vim.bo[ctx.bufnr].filetype ~= "tex" or ctx.trigger.initial_kind == "trigger_character"
              end
            '';
            auto_insert = false;
          };
          menu = {
            # ui2 keeps the global statusline visible above the cmdline
            # (cmdheight reads 1 while it is open); open above the statusline
            # rather than over its mode badge.
            cmdline_position = mkRaw ''
              function()
                local height = math.max(vim.o.cmdheight, 1)
                local statusline = (vim.o.laststatus == 3 and vim.o.cmdheight > 0) and 1 or 0
                return { vim.o.lines - height - statusline, 0 }
              end
            '';
            draw = {
              treesitter = [ "lsp" ];
              columns = [
                { __unkeyed-1 = "kind_icon"; }
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
              max_width = 90;
              max_height = 25;
            };
          };
          ghost_text.enabled = false;
        };
        signature = {
          enabled = true;
          window.show_documentation = true;
        };
        sources = {
          default = [
            "lsp"
            "path"
            "snippets"
            "buffer"
          ];
          providers = {
            # friendly-snippets' language-independent set (date, uuid, lorem)
            # fuzzy-matches single letters in every buffer.
            snippets.opts = {
              global_snippets = mkRaw "{}";
              # friendly-snippets also maps global.json straight to tex,
              # markdown, plaintext and html; its LaTeX sets match prose words
              # (to, for, item) and duplicate texlab's environments.
              filter_snippets = mkRaw ''
                function(_, file)
                  return not (file:match("/global%.json$") or file:match("/latex%.json$") or file:match("vscode%-latex%-snippets%.json$"))
                end
              '';
            };
          };
        };
        cmdline = {
          keymap = {
            preset = "cmdline";
            "<Right>" = false;
            "<Left>" = false;
          };
          completion = {
            list.selection.preselect = false;
            menu.auto_show = mkRaw ''function() return vim.fn.getcmdtype() == ":" end'';
            ghost_text.enabled = false;
          };
        };
        fuzzy = {
          prebuilt_binaries.download = false;
          sorts = [
            "exact"
            "score"
            "sort_text"
          ];
        };
      };
    };
  };
}
