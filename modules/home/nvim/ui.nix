# Gruvbox Material (matching Ghostty and tmux), lualine,
# which-key and snacks.nvim, with LazyVim's picker/explorer/toggle keys.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.lib.nixvim) mkRaw;
  c = import ../../theme.nix;
  map = mode: key: action: desc: {
    inherit mode key;
    action = mkRaw action;
    options = { inherit desc; };
  };
  pick =
    key: source: desc:
    map "n" key "function() Snacks.picker.${source} end" desc;

  # better_performance splits highlights into after/syntax files that the
  # colorscheme writes next to itself on first use. The store is read-only, so
  # generate them at build time and let the plugin find them there.
  gruvbox-material = pkgs.vimPlugins.gruvbox-material.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      substituteInPlace $out/autoload/gruvbox_material.vim \
        --replace-fail "filewritable(plugin_path) == 2)" \
          "(filewritable(plugin_path) == 2 || filereadable(plugin_path . '/after/syntax/text/gruvbox_material.vim')))"
      ${lib.getExe pkgs.neovim-unwrapped} --headless -u NONE -i NONE \
        --cmd "set rtp^=$out" --cmd "let g:gruvbox_material_better_performance = 1" \
        -c "colorscheme gruvbox-material" -c "qall!"
      test -f $out/after/syntax/text/gruvbox_material.vim
    '';
  });

  # lualine bundles a static gruvbox-material theme under the same module name
  # as the colorscheme's own, which follows the configured palette. Drop the
  # static copy so the two can share one combined plugin pack.
  lualine = pkgs.vimPlugins.lualine-nvim.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      rm $out/lua/lualine/themes/gruvbox-material.lua
    '';
  });
in
{
  programs.nixvim = {
    colorschemes.gruvbox-material = {
      enable = true;
      package = gruvbox-material;
      settings = {
        background = "medium";
        foreground = "material";
        enable_italic = 1;
        enable_bold = 1;
        transparent_background = 0;
        float_style = "dim";
        ui_contrast = "high";
        diagnostic_virtual_text = "colored";
        current_word = "grey background";
        sign_column_background = "none";
      };
    };
    # Set outside `settings`: the module warns because better_performance
    # normally needs a writable runtimepath, which the build above replaces.
    globals.gruvbox_material_better_performance = 1;

    extraConfigLuaPre = lib.mkMerge [
      # Neovim's experimental ui2 message/cmdline layer (:h ui2): no hit-enter
      # prompts with cmdheight = 0; messages, vim.notify included, show in a
      # timed float above the statusline and g< / :messages open the pager
      # (capped at 0.9: at full height 0.12 leaves a stale row over the
      # statusline). Order 650 runs right after options (600), so ui2 sees
      # cmdheight = 0 and catches every plugin's startup messages; pcall
      # because the module is private.
      (lib.mkOrder 650 ''
        do
          -- 0.12's ui2 runs the Vimscript matchparen in its cmdline window, then
          -- clears the matches behind its back; the stale IDs raise E803 inside
          -- :IncRename's preview and abort the rename. No pairs there, no
          -- matches. 0.13's Lua matchparen tolerates stale IDs.
          if vim.fn.has("nvim-0.13") == 0 then
            vim.api.nvim_create_autocmd("FileType", {
              pattern = "cmd",
              callback = function(ev)
                local ui2 = package.loaded["vim._core.ui2"]
                if ui2 and ev.buf == ui2.bufs.cmd then
                  vim.bo[ev.buf].matchpairs = ""
                end
              end,
            })
          end
          local ok, err = pcall(function()
            require("vim._core.ui2").enable({ msg = { targets = "msg", pager = { height = 0.9 } } })
          end)
          if not ok then
            vim.schedule(function()
              vim.notify("ui2 disabled: " .. tostring(err), vim.log.levels.WARN)
            end)
          end
        end
      '')
      # Groups gruvbox-material leaves to plugin defaults: borders brighter
      # than every other float, and colours off the palette. Defined before
      # nixvim's `colorscheme` line so the first load runs it, and redone on
      # every :colorscheme (and <leader>ub).
      ''
        vim.api.nvim_create_autocmd("ColorScheme", {
          pattern = "gruvbox-material",
          group = vim.api.nvim_create_augroup("gruvbox_material_extra", {}),
          callback = function()
            local config = vim.fn["gruvbox_material#get_configuration"]()
            local palette = vim.fn["gruvbox_material#get_palette"](config.background, config.foreground, config.colors_override)
            local function link(group, target)
              vim.api.nvim_set_hl(0, group, { link = target })
            end
            for _, group in ipairs({ "BlinkCmpMenuBorder", "BlinkCmpDocBorder", "BlinkCmpSignatureHelpBorder", "DapUIFloatBorder" }) do
              link(group, "FloatBorder")
            end
            link("BlinkCmpMenu", "NormalFloat")
            link("OkMsg", "DiagnosticOk")
            link("CompetiTestCorrect", "DiagnosticOk")
            link("CompetiTestWarning", "DiagnosticWarn")
            link("CompetiTestWrong", "DiagnosticError")
            -- Heading bands tinted like their headings (render-markdown links
            -- them to Diff* groups, which makes H1 dark text on solid blue).
            for level, color in ipairs({ "red", "yellow", "yellow", "green", "blue", "purple" }) do
              vim.fn["gruvbox_material#highlight"]("RenderMarkdownH" .. level .. "Bg", palette.none, palette["bg_visual_" .. color])
            end
          end,
        })
      ''
    ];

    # The statusline and key hints arrive right after the first
    # frame; until then the statusline is blank rather than Vim's default.
    opts.statusline = " ";
    plugins.lualine = {
      enable = true;
      package = lualine;
      lazyLoad.settings.event = "DeferredUIEnter";
      settings = {
        options = {
          theme = "gruvbox-material";
          globalstatus = true;
          disabled_filetypes.statusline = [ "snacks_dashboard" ];
          component_separators = "";
          section_separators = "";
          # lualine's defaults plus the macro events, for the recording badge.
          refresh.events = [
            "WinEnter"
            "BufEnter"
            "BufWritePost"
            "SessionLoadPost"
            "FileChangedShellPost"
            "VimResized"
            "Filetype"
            "CursorMoved"
            "CursorMovedI"
            "ModeChanged"
            "RecordingEnter"
            "RecordingLeave"
          ];
        };
        sections = {
          lualine_a = [ "mode" ];
          lualine_b = [ "branch" ];
          lualine_c = [
            "diagnostics"
            {
              __unkeyed-1 = "filetype";
              icon_only = true;
              separator = "";
              padding = {
                left = 1;
                right = 0;
              };
            }
            {
              __unkeyed-1 = "filename";
              path = 1;
              symbols = {
                modified = " ●";
                readonly = " ";
              };
            }
          ];
          # ui2 shows recording, the search count and the selection size in
          # its cmdline row, which cmdheight = 0 hides.
          lualine_x = [
            {
              __unkeyed-1 = mkRaw ''function() return "󰑋 @" .. vim.fn.reg_recording() end'';
              cond = mkRaw ''function() return vim.fn.reg_recording() ~= "" end'';
              color.fg = c.red;
            }
            "searchcount"
            "selectioncount"
            {
              __unkeyed-1 = "lsp_status";
              color.fg = c.green;
            }
            {
              __unkeyed-1 = "diff";
              source = mkRaw ''
                function()
                  local g = vim.b.gitsigns_status_dict
                  if g then return { added = g.added, modified = g.changed, removed = g.removed } end
                end
              '';
            }
          ];
          lualine_y = [ "progress" ];
          lualine_z = [ "location" ];
        };
        extensions = [ "quickfix" ];
      };
    };

    plugins.which-key = {
      enable = true;
      lazyLoad.settings.event = "DeferredUIEnter";
      settings = {
        preset = "helix";
        spec = [
          {
            __unkeyed-1 = [
              {
                __unkeyed-1 = "<leader><tab>";
                group = "tabs";
              }
              {
                __unkeyed-1 = "<leader>a";
                group = "ai";
              }
              {
                __unkeyed-1 = "<leader>c";
                group = "code";
              }
              {
                __unkeyed-1 = "<leader>d";
                group = "debug";
              }
              {
                __unkeyed-1 = "<leader>dp";
                group = "profiler";
              }
              {
                __unkeyed-1 = "<leader>f";
                group = "file/find";
              }
              {
                __unkeyed-1 = "<leader>g";
                group = "git";
              }
              {
                __unkeyed-1 = "<leader>gh";
                group = "hunks";
              }
              {
                __unkeyed-1 = "<leader>q";
                group = "quit/session";
              }
              {
                __unkeyed-1 = "<leader>s";
                group = "search";
              }
              {
                __unkeyed-1 = "<leader>t";
                group = "test";
              }
              {
                __unkeyed-1 = "<leader>u";
                group = "ui";
              }
              {
                __unkeyed-1 = "<leader>x";
                group = "quickfix";
              }
              {
                __unkeyed-1 = "[";
                group = "prev";
              }
              {
                __unkeyed-1 = "]";
                group = "next";
              }
              {
                __unkeyed-1 = "g";
                group = "goto";
              }
              {
                __unkeyed-1 = "ga";
                group = "calls";
              }
              {
                __unkeyed-1 = "gs";
                group = "surround";
              }
              {
                __unkeyed-1 = "z";
                group = "fold";
              }
              {
                __unkeyed-1 = "<leader>b";
                group = "buffer";
                expand = mkRaw "function() return require('which-key.extras').expand.buf() end";
              }
              {
                __unkeyed-1 = "<leader>w";
                group = "windows";
                proxy = "<c-w>";
                expand = mkRaw "function() return require('which-key.extras').expand.win() end";
              }
            ];
            mode = [
              "n"
              "x"
            ];
          }
        ];
      };
    };

    plugins.snacks = {
      enable = true;
      settings = {
        bigfile.enabled = true;
        quickfile.enabled = true;
        explorer.enabled = true;
        input.enabled = true;
        indent = {
          enabled = true;
          animate.enabled = false;
        };
        scope.enabled = true;
        # Views jump at once; <leader>uS turns the animation on.
        scroll.enabled = false;
        statuscolumn.enabled = true;
        words.enabled = true;
        lazygit = {
          enabled = true;
          # Home Manager's lazygit config (git.nix) is the only source: theme,
          # delta diffs and nvim-remote edits back into this Neovim.
          configure = false;
        };
        picker = {
          enabled = true;
          sources.explorer.layout = {
            preset = "sidebar";
            layout = {
              box = "vertical";
              position = "left";
              width = 28;
              min_width = 24;
              height = 0;
              backdrop = false;
              border = "none";
              # A single search row instead of a three-row bordered box.
              __unkeyed-1 = {
                win = "input";
                height = 1;
                border = "none";
              };
              __unkeyed-2 = {
                win = "list";
                border = "none";
              };
              __unkeyed-3 = {
                win = "preview";
                title = "{preview}";
                height = 0.4;
                border = "top";
              };
            };
          };
        };
        terminal.win.keys =
          let
            # Terminal splits use the same editor/tmux navigation; floats keep the key.
            nav = dir: direction: {
              __unkeyed-1 = "<C-${dir}>";
              __unkeyed-2 = mkRaw ''
                function(self)
                  if self:is_floating() then return "<c-${dir}>" end
                  vim.schedule(function() require("smart-splits").move_cursor_${direction}() end)
                end
              '';
              expr = true;
              mode = "t";
            };
          in
          {
            nav_h = nav "h" "left";
            nav_j = nav "j" "down";
            nav_k = nav "k" "up";
            nav_l = nav "l" "right";
          };
        dashboard = {
          enabled = true;
          preset = {
            header = lib.concatStringsSep "\n" [
              "███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗"
              "████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║"
              "██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║"
              "██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║"
              "██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║"
              "╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝"
            ];
            keys = [
              {
                icon = " ";
                key = "f";
                desc = "Find File";
                action = ":lua Snacks.dashboard.pick('files')";
              }
              {
                icon = " ";
                key = "n";
                desc = "New File";
                action = ":ene | startinsert";
              }
              {
                icon = " ";
                key = "g";
                desc = "Find Text";
                action = ":lua Snacks.dashboard.pick('live_grep')";
              }
              {
                icon = " ";
                key = "r";
                desc = "Recent Files";
                action = ":lua Snacks.dashboard.pick('oldfiles')";
              }
              {
                icon = " ";
                key = "s";
                desc = "Restore Session";
                action = ":lua require('lz.n').trigger_load('persistence.nvim'); require('persistence').load()";
              }
              {
                icon = " ";
                key = "q";
                desc = "Quit";
                action = ":qa";
              }
            ];
          };
          sections = [
            { section = "header"; }
            {
              section = "keys";
              gap = 1;
              padding = 1;
            }
          ];
        };
      };

      # Toggles need Snacks.toggle objects, which have no Nix equivalent.
      luaConfig.post = ''
        Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
        Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
        Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
        Snacks.toggle.diagnostics():map("<leader>ud")
        Snacks.toggle.line_number():map("<leader>ul")
        Snacks.toggle.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2, name = "Conceal Level" }):map("<leader>uc")
        Snacks.toggle.option("showtabline", { off = 0, on = vim.o.showtabline > 0 and vim.o.showtabline or 2, name = "Tabline" }):map("<leader>uA")
        Snacks.toggle.treesitter():map("<leader>uT")
        Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>ub")
        Snacks.toggle.dim():map("<leader>uD")
        Snacks.toggle.animate():map("<leader>ua")
        Snacks.toggle.indent():map("<leader>ug")
        Snacks.toggle.scroll():map("<leader>uS")
        Snacks.toggle.inlay_hints():map("<leader>uh")
        Snacks.toggle.zoom():map("<leader>wm"):map("<leader>uZ")
        Snacks.toggle.zen():map("<leader>uz")
        Snacks.toggle.profiler():map("<leader>dpp")
        Snacks.toggle.profiler_highlights():map("<leader>dph")
        Snacks.toggle({
          name = "Virtual Lines",
          get = function() return not not vim.diagnostic.config().virtual_lines end,
          set = function(on) vim.diagnostic.config({ virtual_lines = on and { current_line = true } or false }) end,
        }):map("<leader>uv")
        Snacks.toggle({
          name = "Git Signs",
          get = function() return package.loaded.gitsigns ~= nil and require("gitsigns.config").config.signcolumn end,
          set = function(on) require("lz.n").trigger_load("gitsigns.nvim"); require("gitsigns").toggle_signs(on) end,
        }):map("<leader>uG")
        Snacks.toggle({
          name = "Git Blame Line",
          get = function() return package.loaded.gitsigns ~= nil and require("gitsigns.config").config.current_line_blame end,
          set = function(on) require("lz.n").trigger_load("gitsigns.nvim"); require("gitsigns").toggle_current_line_blame(on) end,
        }):map("<leader>uB")
        -- Format on save (conform reads these; see format.nix).
        Snacks.toggle({
          name = "Auto Format (Global)",
          get = function() return vim.g.autoformat ~= false end,
          set = function(on) vim.g.autoformat = on; vim.b.autoformat = nil end,
        }):map("<leader>uf")
        Snacks.toggle({
          name = "Auto Format (Buffer)",
          get = function()
            local enabled = vim.b.autoformat
            if enabled == nil then return vim.g.autoformat ~= false end
            return enabled
          end,
          set = function(on) vim.b.autoformat = on end,
        }):map("<leader>uF")
      '';
    };

    keymaps = [
      # Pickers (root = LSP workspace, then git, then cwd).
      (map "n" "<leader><space>" "function() Snacks.picker.files({ cwd = require('core').root() }) end"
        "Find Files (Root Dir)"
      )
      (pick "<leader>fF" "files()" "Find Files (cwd)")
      (pick "<leader>fg" "git_files()" "Find Files (git-files)")
      (pick "<leader>fB" "buffers({ hidden = true, nofile = true })" "Buffers (all)")
      (pick "<leader>fr" "recent()" "Recent")
      (pick "<leader>fR" "recent({ filter = { cwd = true } })" "Recent (cwd)")
      (pick "<leader>," "buffers()" "Buffers")
      (map "n" "<leader>/" "function() Snacks.picker.grep({ cwd = require('core').root() }) end"
        "Grep (Root Dir)"
      )
      (pick "<leader>:" "command_history()" "Command History")
      {
        mode = "n";
        key = "<leader>n";
        action = "<cmd>messages<cr>";
        options.desc = "Message History";
      }
      {
        mode = "n";
        key = "<leader>un";
        action = "<cmd>messages clear<cr>";
        options.desc = "Clear Message History";
      }
      (pick "<leader>sb" "lines()" "Buffer Lines")
      (pick "<leader>sB" "grep_buffers()" "Grep Open Buffers")
      (pick "<leader>sG" "grep()" "Grep (cwd)")
      (map [ "n" "x" ] "<leader>sw"
        "function() Snacks.picker.grep_word({ cwd = require('core').root() }) end"
        "Visual Selection or Word (Root Dir)"
      )
      (map [
        "n"
        "x"
      ] "<leader>sW" "function() Snacks.picker.grep_word() end" "Visual Selection or Word (cwd)")
      (pick "<leader>s\"" "registers()" "Registers")
      (pick "<leader>s/" "search_history()" "Search History")
      (pick "<leader>sa" "autocmds()" "Autocmds")
      (pick "<leader>sc" "command_history()" "Command History")
      (pick "<leader>sC" "commands()" "Commands")
      (pick "<leader>sd" "diagnostics()" "Diagnostics")
      (pick "<leader>sD" "diagnostics_buffer()" "Buffer Diagnostics")
      (pick "<leader>sh" "help()" "Help Pages")
      (pick "<leader>sH" "highlights()" "Highlights")
      (pick "<leader>si" "icons()" "Icons")
      (pick "<leader>sj" "jumps()" "Jumps")
      (pick "<leader>sk" "keymaps()" "Keymaps")
      (pick "<leader>sl" "loclist()" "Location List")
      (pick "<leader>sM" "man()" "Man Pages")
      (pick "<leader>sm" "marks()" "Marks")
      (pick "<leader>sR" "resume()" "Resume")
      (pick "<leader>sq" "qflist()" "Quickfix List")
      (pick "<leader>su" "undo()" "Undotree")
      (pick "<leader>uC" "colorschemes()" "Colorschemes")
      # Explorer.
      (map "n" "<leader>e" "function() Snacks.explorer({ cwd = require('core').root() }) end"
        "Explorer (Root Dir)"
      )
      (map "n" "<leader>E" "function() Snacks.explorer() end" "Explorer (cwd)")
      # Git.
      (map "n" "<leader>gg" "function() Snacks.lazygit({ cwd = require('core').git_root() }) end"
        "Lazygit (Root Dir)"
      )
      (map "n" "<leader>gG" "function() Snacks.lazygit() end" "Lazygit (cwd)")
      (pick "<leader>gl" "git_log({ cwd = require('core').git_root() })" "Git Log")
      (pick "<leader>gL" "git_log()" "Git Log (cwd)")
      (pick "<leader>gb" "git_log_line()" "Git Blame Line")
      (pick "<leader>gf" "git_log_file()" "Git Current File History")
      (pick "<leader>gd" "git_diff()" "Git Diff (hunks)")
      (pick "<leader>gs" "git_status()" "Git Status")
      (pick "<leader>gS" "git_stash()" "Git Stash")
      (map [ "n" "x" ] "<leader>gB" "function() Snacks.gitbrowse() end" "Git Browse (open)")
      (map [ "n" "x" ] "<leader>gY"
        ''function() Snacks.gitbrowse({ open = function(url) vim.fn.setreg("+", url) end, notify = false }) end''
        "Git Browse (copy)"
      )
      # Buffers.
      (map "n" "<leader>bd" "function() Snacks.bufdelete() end" "Delete Buffer")
      (map "n" "<leader>bo" "function() Snacks.bufdelete.other() end" "Delete Other Buffers")
      (map "n" "<leader>bi" "function() Snacks.bufdelete.invisible() end" "Delete Invisible Buffers")
      {
        mode = "n";
        key = "<leader>bD";
        action = "<cmd>bd<cr>";
        options.desc = "Delete Buffer and Window";
      }
      {
        mode = "n";
        key = "<S-h>";
        action = "<cmd>bprevious<cr>";
        options.desc = "Prev Buffer";
      }
      {
        mode = "n";
        key = "<S-l>";
        action = "<cmd>bnext<cr>";
        options.desc = "Next Buffer";
      }
      # Cmd-W, Cmd-G and Cmd-F: tmux forwards them as these Alt chords when the
      # pane is Neovim (terminal.nix), so each acts on the editor. Shells are
      # tmux panes (Cmd-J), not Neovim terminals.
      (map [ "n" "i" "x" "t" ] "<M-w>" "function() require('core').close() end" "Close Buffer or Window")
      (map [ "n" "i" "x" "t" ] "<M-g>"
        "function() Snacks.lazygit({ cwd = require('core').git_root() }) end"
        "Lazygit (Root Dir)"
      )
      (map [
        "n"
        "i"
        "x"
      ] "<M-f>" "function() vim.cmd.stopinsert() vim.api.nvim_feedkeys('/', 'n', false) end" "Search")
      # Scratch, which-key.
      (map "n" "<leader>." "function() Snacks.scratch() end" "Toggle Scratch Buffer")
      (map "n" "<leader>S" "function() Snacks.scratch.select() end" "Select Scratch Buffer")
      (map "n" "<leader>dps" "function() Snacks.profiler.scratch() end" "Profiler Scratch Buffer")
      (map "n" "<leader>?" "function() require('which-key').show({ global = false }) end"
        "Buffer Keymaps (which-key)"
      )
      (map "n" "<c-w><space>" "function() require('which-key').show({ keys = '<c-w>', loop = true }) end"
        "Window Hydra Mode (which-key)"
      )
    ];
  };
}
