{
  pkgs,
  lib,
  ...
}: let
  nlib = lib.nixvim;
in {
  defaultEditor = true;
  nixpkgs.useGlobalPackages = true;

  viAlias = true;
  vimAlias = true;

  withPython3 = false;
  withRuby = false;

  wrapRc = true;

  luaLoader.enable = true;

  performance = {
    byteCompileLua = {
      enable = true;
      configs = true;
      initLua = true;
      luaLib = true;
      nvimRuntime = true;
      plugins = true;
    };
    combinePlugins.enable = true;
  };

  globals = {
    mapleader = " ";
    maplocalleader = ",";

    loaded_2html_plugin = 1;
    loaded_gzip = 1;
    loaded_matchit = 1;
    loaded_matchparen = 1;
    loaded_netrw = 1;
    loaded_netrwPlugin = 1;
    loaded_remote_plugins = 1;
    loaded_tar = 1;
    loaded_tarPlugin = 1;
    loaded_tutor_mode_plugin = 1;
    loaded_zip = 1;
    loaded_zipPlugin = 1;
  };

  opts = {
    number = true;
    relativenumber = true;
    signcolumn = "yes";
    cursorline = true;
    termguicolors = true;

    updatetime = 100;
    timeoutlen = 300;
    ttimeoutlen = 10;
    redrawtime = 1500;

    completeopt = "menu,menuone,noselect";
    pumheight = 12;

    expandtab = true;
    shiftwidth = 2;
    tabstop = 2;
    smartindent = true;

    ignorecase = true;
    smartcase = true;
    inccommand = "split";

    splitbelow = true;
    splitright = true;
    scrolloff = 8;
    sidescrolloff = 8;

    undofile = true;
    swapfile = false;
    backup = false;
    writebackup = false;

    wrap = false;
    linebreak = true;
    breakindent = true;

    clipboard = "unnamedplus";
    mouse = "a";

    # Keep sessions useful without resurrecting transient UI/plugin state.
    sessionoptions = "buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions";

    foldlevel = 99;
    foldlevelstart = 99;
    foldenable = true;
    foldmethod = "expr";
    foldexpr = "v:lua.vim.treesitter.foldexpr()";

    list = true;
    listchars = "tab:  ,trail:.,nbsp:+";

    grepprg = "rg --vimgrep --smart-case";
    grepformat = "%f:%l:%c:%m";
  };

  diagnostic.settings = {
    virtual_text = false;
    virtual_lines = false;
    severity_sort = true;
    update_in_insert = false;
    float = {
      border = "rounded";
      source = "if_many";
    };
    signs = {
      text = {
        "__rawKey__vim.diagnostic.severity.ERROR" = "󰅚 ";
        "__rawKey__vim.diagnostic.severity.WARN" = "󰀪 ";
        "__rawKey__vim.diagnostic.severity.INFO" = "󰋽 ";
        "__rawKey__vim.diagnostic.severity.HINT" = "󰌶 ";
      };
    };
  };

  lsp = {
    inlayHints.enable = true;
    onAttach = ''
      if client:supports_method("textDocument/foldingRange") then
        vim.opt_local.foldexpr = "v:lua.vim.lsp.foldexpr()"
      end
    '';
  };

  colorscheme = "koda";

  extraPlugins = [
    # Main colorscheme: keep this as a start plugin so setup can run before :colorscheme.
    pkgs.vimPlugins.koda-nvim
  ];

  # extraPackages = with pkgs; [
  #   # Core search / VCS / Nix tooling.
  #   alejandra
  #   deadnix
  #   fd
  #   git
  #   lazygit
  #   nixd
  #   ripgrep
  #   statix
  #   stylua
  #   taplo
  #   zellij

  #   # Rust editor-side tooling. Prefer launching nvim from a project devShell
  #   # or direnv shell so cargo/rustc/rustfmt/clippy come from the project
  #   # toolchain. These are here as sane fallbacks and for plugin integrations.
  #   rust-analyzer
  #   rustfmt
  #   clippy
  #   cargo-edit
  #   cargo-expand
  #   cargo-nextest
  #   cargo-watch
  #   bacon
  #   cargo-audit
  #   cargo-deny
  #   cargo-machete
  #   graphviz
  #   marksman
  # ];

  keymaps = [
    {
      key = "<leader>w";
      action = "<cmd>w<cr>";
      options.desc = "Write";
    }
    {
      key = "<leader>q";
      action = "<cmd>q<cr>";
      options.desc = "Quit";
    }
    {
      key = "<leader>e";
      action = nlib.mkRaw "function() vim.diagnostic.open_float() end";
      options.desc = "Line Diagnostics";
    }
    {
      mode = "n";
      key = "<esc>";
      action = "<cmd>nohlsearch<cr>";
      options.desc = "Clear Search";
    }
    {
      mode = "n";
      key = "<leader>tt";
      action = nlib.mkRaw ''
        function()
          vim.diagnostic.config({
            virtual_lines = not vim.diagnostic.config().virtual_lines,
          })
        end
      '';
      options.desc = "Toggle Diagnostic Lines";
    }
    {
      mode = "n";
      key = "<leader>zp";
      action = nlib.mkRaw "function() _G.NixvimSession.pause_lsp() end";
      options.desc = "Pause LSP Clients";
    }
    {
      mode = "n";
      key = "<leader>zr";
      action = nlib.mkRaw "function() _G.NixvimSession.resume_lsp() end";
      options.desc = "Resume LSP Clients";
    }
    {
      mode = "n";
      key = "<leader>zd";
      action = nlib.mkRaw "function() _G.NixvimSession.zellij_detach() end";
      options.desc = "Save, Pause LSP, Detach Zellij";
    }
    {
      mode = "n";
      key = "<leader>zD";
      action = nlib.mkRaw "function() _G.NixvimSession.zellij_hibernate() end";
      options.desc = "Save and Hibernate Zellij";
    }
    {
      mode = "n";
      key = "<leader>zs";
      action = "<cmd>Persisted save<cr>";
      options.desc = "Save Session";
    }
    {
      mode = "n";
      key = "<leader>zl";
      action = "<cmd>Persisted load<cr>";
      options.desc = "Load Session";
    }
    {
      mode = "n";
      key = "<leader>zL";
      action = "<cmd>Persisted load_last<cr>";
      options.desc = "Load Last Session";
    }
    {
      mode = "n";
      key = "<leader>zS";
      action = "<cmd>Persisted select<cr>";
      options.desc = "Select Session";
    }
  ];

  autoCmd = [
    {
      event = "VimEnter";
      once = true;
      desc = "Emit DeferredUIEnter after first UI frame";
      callback = nlib.mkRaw ''
        function()
          vim.defer_fn(function()
            vim.api.nvim_exec_autocmds("User", { pattern = "DeferredUIEnter" })
          end, 10)
        end
      '';
    }
    {
      event = "User";
      pattern = "DeferredUIEnter";
      once = true;
      desc = "Use Snacks notifier after Snacks has loaded";
      callback = nlib.mkRaw ''
        function()
          if package.loaded["snacks"] and _G.Snacks and Snacks.notifier then
            vim.notify = Snacks.notifier.notify
          end
        end
      '';
    }

    {
      event = "FocusLost";
      desc = "Save session and debounce LSP hibernation when Neovim is left";
      callback = nlib.mkRaw ''
        function()
          _G.NixvimSession.save_all({ quiet = true })
          _G.NixvimSession.schedule_pause_lsp({ quiet = true, delay = 15000 })
        end
      '';
    }
    {
      event = "VimLeavePre";
      desc = "Persist Neovim and serialize Zellij before nvim exits";
      callback = nlib.mkRaw "function() _G.NixvimSession.save_all({ quiet = true }) end";
    }
    {
      event = "VimSuspend";
      desc = "Persist Neovim and pause LSP before terminal suspend";
      callback = nlib.mkRaw ''
        function()
          _G.NixvimSession.save_all({ quiet = true })
          _G.NixvimSession.pause_lsp({ quiet = true })
        end
      '';
    }
    {
      event = [
        "FocusGained"
        "VimResume"
      ];
      desc = "Refresh buffers and revive LSP after session resume";
      callback = nlib.mkRaw ''
        function()
          _G.NixvimSession.mark_focused()
          _G.NixvimSession.resume_lsp({ quiet = true, only_if_empty = true })
        end
      '';
    }

    {
      event = "FileType";
      pattern = "rust";
      desc = "Rust buffer-local editor options and cargo helpers";
      callback = nlib.mkRaw ''
        function(args)
          vim.opt_local.shiftwidth = 4
          vim.opt_local.tabstop = 4
          vim.opt_local.softtabstop = 4
          vim.opt_local.expandtab = true
          vim.opt_local.colorcolumn = "100"

          local function term(cmd)
            vim.cmd("botright 15split")
            vim.fn.termopen(cmd, { cwd = vim.fn.getcwd() })
            vim.cmd("startinsert")
          end

          local opts = { buffer = args.buf, silent = true }
          vim.keymap.set("n", "<leader>rb", function() term({ "bacon", "clippy" }) end, vim.tbl_extend("force", opts, { desc = "Bacon Clippy" }))
          vim.keymap.set("n", "<leader>rw", function() term({ "cargo", "watch", "-x", "check --all-targets --all-features" }) end, vim.tbl_extend("force", opts, { desc = "Cargo Watch Check" }))
          vim.keymap.set("n", "<leader>rx", function() term({ "cargo", "expand" }) end, vim.tbl_extend("force", opts, { desc = "Cargo Expand" }))
          vim.keymap.set("n", "<leader>rn", function() term({ "cargo", "nextest", "run" }) end, vim.tbl_extend("force", opts, { desc = "Cargo Nextest" }))
        end
      '';
    }
  ];

  plugins = {
    zellij-nav = {
      enable = true;
      autoLoad = false;
      callSetup = true;
      settings = {};
      lazyLoad = {
        enable = true;
        settings = {
          enabled = nlib.mkRaw ''
            function()
              return vim.env.ZELLIJ ~= nil
            end
          '';
          cmd = [
            "ZellijNavigateLeft"
            "ZellijNavigateDown"
            "ZellijNavigateUp"
            "ZellijNavigateRight"
            "ZellijNavigateLeftTab"
            "ZellijNavigateDownTab"
            "ZellijNavigateUpTab"
            "ZellijNavigateRightTab"
          ];
        };
      };
    };

    yanky = {
      enable = true;
      autoLoad = false;
      settings = {
        ring = {
          history_length = 100;
          storage = "shada";
          sync_with_numbered_registers = true;
          cancel_event = "update";
          ignore_registers = ["_"];
          update_register_on_cycle = false;
        };
        system_clipboard.sync_with_ring = true;
        highlight = {
          on_yank = true;
          on_put = true;
          timer = 120;
        };
        preserve_cursor_position.enabled = true;
        textobj.enabled = true;
      };
      lazyLoad = {
        enable = true;
        settings = {
          cmd = [
            "YankyRingHistory"
            "YankyClearHistory"
          ];
        };
      };
    };

    lz-n = {
      enable = true;
      keymaps = [
        {
          plugin = "zellij-nav.nvim";
          mode = "n";
          key = "<C-h>";
          action = "<cmd>ZellijNavigateLeft<cr>";
          options = {
            silent = true;
            desc = "Window/Zellij Left";
          };
        }
        {
          plugin = "zellij-nav.nvim";
          mode = "n";
          key = "<C-j>";
          action = "<cmd>ZellijNavigateDown<cr>";
          options = {
            silent = true;
            desc = "Window/Zellij Down";
          };
        }
        {
          plugin = "zellij-nav.nvim";
          mode = "n";
          key = "<C-k>";
          action = "<cmd>ZellijNavigateUp<cr>";
          options = {
            silent = true;
            desc = "Window/Zellij Up";
          };
        }
        {
          plugin = "zellij-nav.nvim";
          mode = "n";
          key = "<C-l>";
          action = "<cmd>ZellijNavigateRight<cr>";
          options = {
            silent = true;
            desc = "Window/Zellij Right";
          };
        }
        {
          plugin = "zellij-nav.nvim";
          mode = "n";
          key = "<A-h>";
          action = "<cmd>ZellijNavigateLeftTab<cr>";
          options = {
            silent = true;
            desc = "Zellij Tab Left";
          };
        }
        {
          plugin = "zellij-nav.nvim";
          mode = "n";
          key = "<A-l>";
          action = "<cmd>ZellijNavigateRightTab<cr>";
          options = {
            silent = true;
            desc = "Zellij Tab Right";
          };
        }

        {
          plugin = "yanky.nvim";
          mode = ["n" "x"];
          key = "y";
          action = "<Plug>(YankyYank)";
          options = {
            silent = true;
            remap = true;
            desc = "Yank Text";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = ["n" "x"];
          key = "p";
          action = "<Plug>(YankyPutAfter)";
          options = {
            silent = true;
            remap = true;
            desc = "Put Text After";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = ["n" "x"];
          key = "P";
          action = "<Plug>(YankyPutBefore)";
          options = {
            silent = true;
            remap = true;
            desc = "Put Text Before";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = ["n" "x"];
          key = "gp";
          action = "<Plug>(YankyGPutAfter)";
          options = {
            silent = true;
            remap = true;
            desc = "Put Text After Selection";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = ["n" "x"];
          key = "gP";
          action = "<Plug>(YankyGPutBefore)";
          options = {
            silent = true;
            remap = true;
            desc = "Put Text Before Selection";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = "n";
          key = "]y";
          action = "<Plug>(YankyCycleForward)";
          options = {
            silent = true;
            remap = true;
            desc = "Next Yank";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = "n";
          key = "[y";
          action = "<Plug>(YankyCycleBackward)";
          options = {
            silent = true;
            remap = true;
            desc = "Previous Yank";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = "n";
          key = "]p";
          action = "<Plug>(YankyPutIndentAfterLinewise)";
          options = {
            silent = true;
            remap = true;
            desc = "Put Indented After";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = "n";
          key = "[p";
          action = "<Plug>(YankyPutIndentBeforeLinewise)";
          options = {
            silent = true;
            remap = true;
            desc = "Put Indented Before";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = "n";
          key = "]P";
          action = "<Plug>(YankyPutIndentAfterLinewise)";
          options = {
            silent = true;
            remap = true;
            desc = "Put Indented After Before-Cursor";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = "n";
          key = "[P";
          action = "<Plug>(YankyPutIndentBeforeLinewise)";
          options = {
            silent = true;
            remap = true;
            desc = "Put Indented Before Before-Cursor";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = "n";
          key = ">p";
          action = "<Plug>(YankyPutIndentAfterShiftRight)";
          options = {
            silent = true;
            remap = true;
            desc = "Put and Shift Right";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = "n";
          key = "<p";
          action = "<Plug>(YankyPutIndentAfterShiftLeft)";
          options = {
            silent = true;
            remap = true;
            desc = "Put and Shift Left";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = "n";
          key = ">P";
          action = "<Plug>(YankyPutIndentBeforeShiftRight)";
          options = {
            silent = true;
            remap = true;
            desc = "Put Before and Shift Right";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = "n";
          key = "<P";
          action = "<Plug>(YankyPutIndentBeforeShiftLeft)";
          options = {
            silent = true;
            remap = true;
            desc = "Put Before and Shift Left";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = "n";
          key = "=p";
          action = "<Plug>(YankyPutAfterFilter)";
          options = {
            silent = true;
            remap = true;
            desc = "Put After Filter";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = "n";
          key = "=P";
          action = "<Plug>(YankyPutBeforeFilter)";
          options = {
            silent = true;
            remap = true;
            desc = "Put Before Filter";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = ["o" "x"];
          key = "iy";
          action = nlib.mkRaw ''
            function()
              require("yanky.textobj").last_put()
            end
          '';
          options = {
            silent = true;
            desc = "Last Put Text";
          };
        }
        {
          plugin = "yanky.nvim";
          mode = ["n" "x"];
          key = "<leader>p";
          action = nlib.mkRaw ''
            function()
              _G.NixvimLoad.plugin("snacks.nvim")
              if _G.Snacks and Snacks.picker and Snacks.picker.yanky then
                Snacks.picker.yanky()
              else
                vim.cmd("YankyRingHistory")
              end
            end
          '';
          options = {
            silent = true;
            desc = "Yank History";
          };
        }

        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader><space>";
          action = nlib.mkRaw ''function() Snacks.picker.smart() end'';
          options = {
            silent = true;
            desc = "Smart Find";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>ff";
          action = nlib.mkRaw ''function() Snacks.picker.files({ hidden = true, ignored = true }) end'';
          options = {
            silent = true;
            desc = "Files";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>fg";
          action = nlib.mkRaw ''function() Snacks.picker.grep() end'';
          options = {
            silent = true;
            desc = "Grep";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = ["n" "x"];
          key = "<leader>fw";
          action = nlib.mkRaw ''function() Snacks.picker.grep_word() end'';
          options = {
            silent = true;
            desc = "Grep Word";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>fb";
          action = nlib.mkRaw ''function() Snacks.picker.buffers({ sort_lastused = true }) end'';
          options = {
            silent = true;
            desc = "Buffers";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>fr";
          action = nlib.mkRaw ''function() Snacks.picker.recent() end'';
          options = {
            silent = true;
            desc = "Recent Files";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>fR";
          action = nlib.mkRaw ''function() Snacks.picker.resume() end'';
          options = {
            silent = true;
            desc = "Resume Picker";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>fh";
          action = nlib.mkRaw ''function() Snacks.picker.help() end'';
          options = {
            silent = true;
            desc = "Help";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>fk";
          action = nlib.mkRaw ''function() Snacks.picker.keymaps() end'';
          options = {
            silent = true;
            desc = "Keymaps";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>sd";
          action = nlib.mkRaw ''function() Snacks.picker.diagnostics() end'';
          options = {
            silent = true;
            desc = "Diagnostics";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>sD";
          action = nlib.mkRaw ''function() Snacks.picker.diagnostics_buffer() end'';
          options = {
            silent = true;
            desc = "Buffer Diagnostics";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>ss";
          action = nlib.mkRaw ''function() Snacks.picker.lsp_symbols() end'';
          options = {
            silent = true;
            desc = "Document Symbols";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>sS";
          action = nlib.mkRaw ''function() Snacks.picker.lsp_workspace_symbols() end'';
          options = {
            silent = true;
            desc = "Workspace Symbols";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "gd";
          action = nlib.mkRaw ''function() Snacks.picker.lsp_definitions() end'';
          options = {
            silent = true;
            desc = "Goto Definition";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "gD";
          action = nlib.mkRaw ''function() vim.lsp.buf.declaration() end'';
          options = {
            silent = true;
            desc = "Goto Declaration";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "gr";
          action = nlib.mkRaw ''function() Snacks.picker.lsp_references() end'';
          options = {
            silent = true;
            desc = "References";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "gi";
          action = nlib.mkRaw ''function() Snacks.picker.lsp_implementations() end'';
          options = {
            silent = true;
            desc = "Implementations";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "gy";
          action = nlib.mkRaw ''function() Snacks.picker.lsp_type_definitions() end'';
          options = {
            silent = true;
            desc = "Type Definitions";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>n";
          action = nlib.mkRaw ''function() Snacks.explorer() end'';
          options = {
            silent = true;
            desc = "Explorer";
          };
        }

        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rr";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp('runnables') end'';
          options = {
            silent = true;
            desc = "Rust Runnables";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>ra";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp('codeAction') end'';
          options = {
            silent = true;
            desc = "Rust Code Action";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>re";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp('explainError') end'';
          options = {
            silent = true;
            desc = "Explain Rust Error";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rm";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp('expandMacro') end'';
          options = {
            silent = true;
            desc = "Expand Macro";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rS";
          action = nlib.mkRaw ''function() _G.NixvimLoad.plugin('nvim-treesitter'); vim.cmd.RustLsp('syntaxTree') end'';
          options = {
            silent = true;
            desc = "Rust Syntax Tree";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rf";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp({ 'flyCheck', 'run' }) end'';
          options = {
            silent = true;
            desc = "Rust Fly Check";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rh";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp({ 'hover', 'actions' }) end'';
          options = {
            silent = true;
            desc = "Rust Hover Actions";
          };
        }

        {
          plugin = "crates.nvim";
          mode = "n";
          key = "<leader>ct";
          action = nlib.mkRaw ''function() require('crates').toggle() end'';
          options = {
            silent = true;
            desc = "Toggle Crates";
          };
        }
        {
          plugin = "crates.nvim";
          mode = "n";
          key = "<leader>cu";
          action = nlib.mkRaw ''function() require('crates').upgrade_crate() end'';
          options = {
            silent = true;
            desc = "Upgrade Crate";
          };
        }
        {
          plugin = "crates.nvim";
          mode = "n";
          key = "<leader>cv";
          action = nlib.mkRaw ''function() require('crates').show_versions_popup() end'';
          options = {
            silent = true;
            desc = "Crate Versions";
          };
        }

        {
          plugin = "conform.nvim";
          mode = "n";
          key = "<leader>lf";
          action = nlib.mkRaw ''function() require('conform').format({ async = true, lsp_format = 'fallback' }) end'';
          options = {
            silent = true;
            desc = "Format";
          };
        }

        {
          plugin = "gitsigns.nvim";
          mode = "n";
          key = "]h";
          action = nlib.mkRaw ''function() require('gitsigns').nav_hunk('next') end'';
          options = {
            silent = true;
            desc = "Next Hunk";
          };
        }
        {
          plugin = "gitsigns.nvim";
          mode = "n";
          key = "[h";
          action = nlib.mkRaw ''function() require('gitsigns').nav_hunk('prev') end'';
          options = {
            silent = true;
            desc = "Previous Hunk";
          };
        }
        {
          plugin = "gitsigns.nvim";
          mode = "n";
          key = "<leader>hs";
          action = nlib.mkRaw ''function() require('gitsigns').stage_hunk() end'';
          options = {
            silent = true;
            desc = "Stage Hunk";
          };
        }
        {
          plugin = "gitsigns.nvim";
          mode = "n";
          key = "<leader>hr";
          action = nlib.mkRaw ''function() require('gitsigns').reset_hunk() end'';
          options = {
            silent = true;
            desc = "Reset Hunk";
          };
        }
        {
          plugin = "gitsigns.nvim";
          mode = "n";
          key = "<leader>hp";
          action = nlib.mkRaw ''function() require('gitsigns').preview_hunk_inline() end'';
          options = {
            silent = true;
            desc = "Preview Hunk";
          };
        }
        {
          plugin = "gitsigns.nvim";
          mode = "n";
          key = "<leader>hb";
          action = nlib.mkRaw ''function() require('gitsigns').blame_line({ full = true }) end'';
          options = {
            silent = true;
            desc = "Blame Line";
          };
        }
        {
          plugin = "gitsigns.nvim";
          mode = ["o" "x"];
          key = "ih";
          action = nlib.mkRaw ''function() require('gitsigns').select_hunk() end'';
          options = {
            silent = true;
            desc = "Git Hunk Textobject";
          };
        }

        {
          plugin = "flash.nvim";
          mode = ["n" "x" "o"];
          key = "s";
          action = nlib.mkRaw ''function() require('flash').jump() end'';
          options = {
            silent = true;
            desc = "Flash";
          };
        }
        {
          plugin = "flash.nvim";
          mode = ["n" "x" "o"];
          key = "S";
          action = nlib.mkRaw ''function() _G.NixvimLoad.plugin('nvim-treesitter'); require('flash').treesitter() end'';
          options = {
            silent = true;
            desc = "Flash Treesitter";
          };
        }
        {
          plugin = "flash.nvim";
          mode = "o";
          key = "r";
          action = nlib.mkRaw ''function() require('flash').remote() end'';
          options = {
            silent = true;
            desc = "Remote Flash";
          };
        }
        {
          plugin = "flash.nvim";
          mode = ["o" "x"];
          key = "R";
          action = nlib.mkRaw ''function() _G.NixvimLoad.plugin('nvim-treesitter'); require('flash').treesitter_search() end'';
          options = {
            silent = true;
            desc = "Treesitter Search";
          };
        }

        {
          plugin = "tiny-inline-diagnostic.nvim";
          mode = "n";
          key = "<leader>xi";
          action = nlib.mkRaw ''function() require('tiny-inline-diagnostic').toggle() end'';
          options = {
            silent = true;
            desc = "Toggle Inline Diagnostics";
          };
        }
        {
          plugin = "trouble.nvim";
          mode = "n";
          key = "<leader>xx";
          action = "<cmd>Trouble diagnostics toggle<cr>";
          options = {
            silent = true;
            desc = "Diagnostics";
          };
        }
        {
          plugin = "trouble.nvim";
          mode = "n";
          key = "<leader>xq";
          action = "<cmd>Trouble qflist toggle<cr>";
          options = {
            silent = true;
            desc = "Quickfix";
          };
        }

        {
          plugin = "todo-comments.nvim";
          mode = "n";
          key = "]t";
          action = nlib.mkRaw ''function() require('todo-comments').jump_next() end'';
          options = {
            silent = true;
            desc = "Next Todo";
          };
        }
        {
          plugin = "todo-comments.nvim";
          mode = "n";
          key = "[t";
          action = nlib.mkRaw ''function() require('todo-comments').jump_prev() end'';
          options = {
            silent = true;
            desc = "Previous Todo";
          };
        }
        {
          plugin = "todo-comments.nvim";
          mode = "n";
          key = "<leader>st";
          action = nlib.mkRaw ''function() _G.NixvimLoad.plugin('snacks.nvim'); if Snacks and Snacks.picker and Snacks.picker.todo_comments then Snacks.picker.todo_comments() else vim.cmd('TodoQuickFix') end end'';
          options = {
            silent = true;
            desc = "Todo Picker";
          };
        }
        {
          plugin = "todo-comments.nvim";
          mode = "n";
          key = "<leader>sT";
          action = nlib.mkRaw ''function() _G.NixvimLoad.plugin('trouble.nvim'); vim.cmd('TodoTrouble') end'';
          options = {
            silent = true;
            desc = "Todo Trouble";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>,";
          action = nlib.mkRaw ''function() Snacks.picker.buffers({ sort_lastused = true }) end'';
          options = {
            silent = true;
            desc = "Buffers";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>/";
          action = nlib.mkRaw ''function() Snacks.picker.grep() end'';
          options = {
            silent = true;
            desc = "Grep";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>:";
          action = nlib.mkRaw ''function() Snacks.picker.command_history() end'';
          options = {
            silent = true;
            desc = "Command History";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>fF";
          action = nlib.mkRaw ''function() Snacks.picker.files({ hidden = true, ignored = true, dirs = { vim.fn.getcwd() } }) end'';
          options = {
            silent = true;
            desc = "Files (cwd)";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>fc";
          action = nlib.mkRaw ''function() Snacks.picker.commands() end'';
          options = {
            silent = true;
            desc = "Commands";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>fn";
          action = nlib.mkRaw ''function() Snacks.picker.notifications() end'';
          options = {
            silent = true;
            desc = "Notifications";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>fp";
          action = nlib.mkRaw ''function() Snacks.picker.projects() end'';
          options = {
            silent = true;
            desc = "Projects";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>fG";
          action = nlib.mkRaw ''function() Snacks.picker.git_files() end'';
          options = {
            silent = true;
            desc = "Git Files";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>s/";
          action = nlib.mkRaw ''function() Snacks.picker.search_history() end'';
          options = {
            silent = true;
            desc = "Search History";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>s\"";
          action = nlib.mkRaw ''function() Snacks.picker.registers() end'';
          options = {
            silent = true;
            desc = "Registers";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>sb";
          action = nlib.mkRaw ''function() Snacks.picker.lines() end'';
          options = {
            silent = true;
            desc = "Buffer Lines";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>sB";
          action = nlib.mkRaw ''function() Snacks.picker.grep_buffers() end'';
          options = {
            silent = true;
            desc = "Grep Open Buffers";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>sc";
          action = nlib.mkRaw ''function() Snacks.picker.command_history() end'';
          options = {
            silent = true;
            desc = "Command History";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>sC";
          action = nlib.mkRaw ''function() Snacks.picker.commands() end'';
          options = {
            silent = true;
            desc = "Commands";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>sH";
          action = nlib.mkRaw ''function() Snacks.picker.highlights() end'';
          options = {
            silent = true;
            desc = "Highlights";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>si";
          action = nlib.mkRaw ''function() Snacks.picker.icons() end'';
          options = {
            silent = true;
            desc = "Icons";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>sj";
          action = nlib.mkRaw ''function() Snacks.picker.jumps() end'';
          options = {
            silent = true;
            desc = "Jumps";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>sl";
          action = nlib.mkRaw ''function() Snacks.picker.loclist() end'';
          options = {
            silent = true;
            desc = "Location List";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>sm";
          action = nlib.mkRaw ''function() Snacks.picker.marks() end'';
          options = {
            silent = true;
            desc = "Marks";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>sM";
          action = nlib.mkRaw ''function() Snacks.picker.man() end'';
          options = {
            silent = true;
            desc = "Man Pages";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>sq";
          action = nlib.mkRaw ''function() Snacks.picker.qflist() end'';
          options = {
            silent = true;
            desc = "Quickfix List";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>su";
          action = nlib.mkRaw ''function() Snacks.picker.undo() end'';
          options = {
            silent = true;
            desc = "Undo History";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "gai";
          action = nlib.mkRaw ''function() Snacks.picker.lsp_incoming_calls() end'';
          options = {
            silent = true;
            desc = "Incoming Calls";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "gao";
          action = nlib.mkRaw ''function() Snacks.picker.lsp_outgoing_calls() end'';
          options = {
            silent = true;
            desc = "Outgoing Calls";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>gb";
          action = nlib.mkRaw ''function() Snacks.picker.git_branches() end'';
          options = {
            silent = true;
            desc = "Git Branches";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>gs";
          action = nlib.mkRaw ''function() Snacks.picker.git_status() end'';
          options = {
            silent = true;
            desc = "Git Status";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>gl";
          action = nlib.mkRaw ''function() Snacks.picker.git_log() end'';
          options = {
            silent = true;
            desc = "Git Log";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>gL";
          action = nlib.mkRaw ''function() Snacks.picker.git_log_file() end'';
          options = {
            silent = true;
            desc = "Git Log File";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>gd";
          action = nlib.mkRaw ''function() Snacks.picker.git_diff() end'';
          options = {
            silent = true;
            desc = "Git Diff";
          };
        }
        {
          plugin = "snacks.nvim";
          mode = "n";
          key = "<leader>gS";
          action = nlib.mkRaw ''function() Snacks.picker.git_stash() end'';
          options = {
            silent = true;
            desc = "Git Stash";
          };
        }

        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rR";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp({ 'runnables', bang = true }) end'';
          options = {
            silent = true;
            desc = "Rust Last Runnable";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rt";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp('testables') end'';
          options = {
            silent = true;
            desc = "Rust Testables";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rT";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp({ 'testables', bang = true }) end'';
          options = {
            silent = true;
            desc = "Rust Last Testable";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rE";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp('renderDiagnostic') end'';
          options = {
            silent = true;
            desc = "Render Rust Diagnostic";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rl";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp('relatedDiagnostics') end'';
          options = {
            silent = true;
            desc = "Related Diagnostics";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rk";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp('relatedTests') end'';
          options = {
            silent = true;
            desc = "Related Tests";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rW";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp({ 'workspaceSymbol', 'allSymbols', bang = true }) end'';
          options = {
            silent = true;
            desc = "Rust Workspace Symbols";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rM";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp('rebuildProcMacros') end'';
          options = {
            silent = true;
            desc = "Rebuild Proc Macros";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rc";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp('openCargo') end'';
          options = {
            silent = true;
            desc = "Open Cargo.toml";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rC";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp({ 'crateGraph', 'dot', vim.fn.expand('%:p:h') .. '/crate-graph.dot' }) end'';
          options = {
            silent = true;
            desc = "Crate Graph";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>ro";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp('openDocs') end'';
          options = {
            silent = true;
            desc = "Open docs.rs";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rp";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp('parentModule') end'';
          options = {
            silent = true;
            desc = "Parent Module";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = ["n" "v"];
          key = "<leader>rj";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp('joinLines') end'';
          options = {
            silent = true;
            desc = "Rust Join Lines";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = ["n" "v"];
          key = "<leader>rs";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp('ssr') end'';
          options = {
            silent = true;
            desc = "Structural Search Replace";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rF";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp({ 'flyCheck', 'cancel' }) end'';
          options = {
            silent = true;
            desc = "Cancel Rust Fly Check";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rH";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp({ 'view', 'hir' }) end'';
          options = {
            silent = true;
            desc = "View HIR";
          };
        }
        {
          plugin = "rustaceanvim";
          mode = "n";
          key = "<leader>rV";
          action = nlib.mkRaw ''function() vim.cmd.RustLsp({ 'view', 'mir' }) end'';
          options = {
            silent = true;
            desc = "View MIR";
          };
        }

        {
          plugin = "crates.nvim";
          mode = "v";
          key = "<leader>cu";
          action = nlib.mkRaw ''function() require('crates').upgrade_crates() end'';
          options = {
            silent = true;
            desc = "Upgrade Crates";
          };
        }
        {
          plugin = "crates.nvim";
          mode = "n";
          key = "<leader>cU";
          action = nlib.mkRaw ''function() require('crates').upgrade_all_crates() end'';
          options = {
            silent = true;
            desc = "Upgrade All Crates";
          };
        }
        {
          plugin = "crates.nvim";
          mode = "n";
          key = "<leader>cf";
          action = nlib.mkRaw ''function() require('crates').show_features_popup() end'';
          options = {
            silent = true;
            desc = "Crate Features";
          };
        }
        {
          plugin = "crates.nvim";
          mode = "n";
          key = "<leader>cd";
          action = nlib.mkRaw ''function() require('crates').show_dependencies_popup() end'';
          options = {
            silent = true;
            desc = "Crate Dependencies";
          };
        }
        {
          plugin = "crates.nvim";
          mode = "n";
          key = "<leader>cr";
          action = nlib.mkRaw ''function() require('crates').reload() end'';
          options = {
            silent = true;
            desc = "Reload Crates";
          };
        }

        {
          plugin = "flash.nvim";
          mode = "c";
          key = "<c-s>";
          action = nlib.mkRaw ''function() require('flash').toggle() end'';
          options = {
            silent = true;
            desc = "Toggle Flash Search";
          };
        }
        {
          plugin = "tiny-inline-diagnostic.nvim";
          mode = "n";
          key = "<leader>xI";
          action = nlib.mkRaw ''function() require('tiny-inline-diagnostic').toggle_cursor_only() end'';
          options = {
            silent = true;
            desc = "Toggle Cursor Diagnostics";
          };
        }
        {
          plugin = "tiny-inline-diagnostic.nvim";
          mode = "n";
          key = "<leader>xA";
          action = nlib.mkRaw ''function() require('tiny-inline-diagnostic').toggle_all_diags_on_cursorline() end'';
          options = {
            silent = true;
            desc = "Toggle Line Diagnostics";
          };
        }
        {
          plugin = "tiny-inline-diagnostic.nvim";
          mode = "n";
          key = "<leader>xE";
          action = nlib.mkRaw ''function() require('tiny-inline-diagnostic').enable() end'';
          options = {
            silent = true;
            desc = "Enable Inline Diagnostics";
          };
        }
        {
          plugin = "tiny-inline-diagnostic.nvim";
          mode = "n";
          key = "<leader>xD";
          action = nlib.mkRaw ''function() require('tiny-inline-diagnostic').disable() end'';
          options = {
            silent = true;
            desc = "Disable Inline Diagnostics";
          };
        }
        {
          plugin = "tiny-inline-diagnostic.nvim";
          mode = "n";
          key = "<leader>xR";
          action = nlib.mkRaw ''function() require('tiny-inline-diagnostic').reset() end'';
          options = {
            silent = true;
            desc = "Reset Inline Diagnostics";
          };
        }
        {
          plugin = "trouble.nvim";
          mode = "n";
          key = "<leader>xX";
          action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>";
          options = {
            silent = true;
            desc = "Buffer Diagnostics";
          };
        }
        {
          plugin = "trouble.nvim";
          mode = "n";
          key = "<leader>xs";
          action = "<cmd>Trouble symbols toggle focus=false<cr>";
          options = {
            silent = true;
            desc = "Symbols";
          };
        }
        {
          plugin = "trouble.nvim";
          mode = "n";
          key = "<leader>xl";
          action = "<cmd>Trouble lsp toggle focus=false win.position=right<cr>";
          options = {
            silent = true;
            desc = "LSP";
          };
        }
        {
          plugin = "trouble.nvim";
          mode = "n";
          key = "<leader>xL";
          action = "<cmd>Trouble loclist toggle<cr>";
          options = {
            silent = true;
            desc = "Location List";
          };
        }
      ];
    };

    persisted = {
      enable = true;
      lazyLoad = {
        enable = true;
        settings = {
          event = "DeferredUIEnter";
          cmd = "Persisted";
        };
      };
      settings = {
        autostart = true;
        autoload = true;
        follow_cwd = true;
        use_git_branch = true;
        save_dir = nlib.mkRaw ''vim.fn.expand(vim.fn.stdpath("data") .. "/sessions/")'';
        should_save = nlib.mkRaw ''
          function()
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
              if vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= "" then
                return true
              end
            end
            return false
          end
        '';
      };
    };

    snacks = {
      enable = true;
      lazyLoad = {
        enable = true;
        settings = {
          before = nlib.mkRaw ''
            function()
              _G.NixvimLoad.plugin("mini.nvim")
            end
          '';
          event = "DeferredUIEnter";
        };
      };
      settings = {
        bigfile = {
          enabled = true;
          size = 1.5 * 1024 * 1024;
        };
        quickfile.enabled = true;
        input.enabled = true;
        indent = {
          enabled = true;
          animate.enabled = false;
          scope.enabled = true;
        };
        notifier = {
          enabled = true;
          timeout = 2500;
          style = "compact";
        };
        picker = {
          enabled = true;
          ui_select = true;
          sources = {
            explorer = {
              hidden = true;
              ignored = true;
              auto_close = true;
              layout.preset = "sidebar";
            };
          };
          matcher = {
            frecency = true;
            cwd_bonus = true;
            sort_empty = true;
            history_bonus = true;
          };
          layout = {
            preset = "ivy";
          };
          icons = {
            enabled = true;
            files.enabled = true;
            keymaps.nowait = "󰓅 ";
          };
          formatters = {
            file = {
              filename_first = false;
              truncate = 80;
              git_status_hl = true;
            };
          };
          win = {
            input = {
              keys = {
                "<a-s>" = {
                  __unkeyed-1 = "flash";
                  mode = [
                    "n"
                    "i"
                  ];
                };
                "<a-t>" = {
                  __unkeyed-1 = "trouble_open";
                  mode = [
                    "n"
                    "i"
                  ];
                };
                "s" = {
                  __unkeyed-1 = "flash";
                };
              };
            };
          };
          actions = {
            flash = nlib.mkRaw ''
              function(picker)
                _G.NixvimLoad.plugin("flash.nvim")
                require("flash").jump({
                  pattern = "^",
                  label = { after = { 0, 0 } },
                  search = {
                    mode = "search",
                    exclude = {
                      function(win)
                        return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "snacks_picker_list"
                      end,
                    },
                  },
                  action = function(match)
                    local idx = picker.list:row2idx(match.pos[1])
                    picker.list:_move(idx, true, true)
                  end,
                })
              end
            '';
            trouble_open = nlib.mkRaw ''
              function(...)
                _G.NixvimLoad.plugin("trouble.nvim")
                return require("trouble.sources.snacks").actions.trouble_open.action(...)
              end
            '';
          };
        };
        explorer = {
          enabled = true;
          replace_netrw = true;
        };
        statuscolumn = {
          enabled = true;
          left = [
            "mark"
            "sign"
          ];
          right = [
            "fold"
            "git"
          ];
          folds.open = false;
          git.patterns = [
            "GitSign"
            "MiniDiffSign"
          ];
        };
        words = {
          enabled = true;
          debounce = 120;
          notify_jump = false;
          notify_end = false;
        };
      };
    };

    which-key = {
      enable = true;
      lazyLoad = {
        enable = true;
        settings = {
          before = nlib.mkRaw ''
            function()
              _G.NixvimLoad.plugin("mini.nvim")
            end
          '';
          event = "DeferredUIEnter";
        };
      };
      settings = {
        preset = "helix";
        delay = 250;
        notify = false;
        win.border = "rounded";
        spec = [
          {
            __unkeyed-1 = "<leader>f";
            group = "find";
          }
          {
            __unkeyed-1 = "<leader>g";
            group = "git";
          }
          {
            __unkeyed-1 = "<leader>c";
            group = "crates";
          }
          {
            __unkeyed-1 = "<leader>h";
            group = "hunks";
          }
          {
            __unkeyed-1 = "<leader>l";
            group = "lsp";
          }
          {
            __unkeyed-1 = "<leader>r";
            group = "rust";
          }
          {
            __unkeyed-1 = "<leader>s";
            group = "search";
          }
          {
            __unkeyed-1 = "<leader>t";
            group = "test/toggle";
          }
          {
            __unkeyed-1 = "<leader>x";
            group = "diagnostics";
          }
          {
            __unkeyed-1 = "<leader>z";
            group = "zellij/session";
          }
        ];
      };
    };

    blink-cmp = {
      enable = true;
      setupLspCapabilities = false;
      lazyLoad = {
        enable = true;
        settings = {
          before = nlib.mkRaw ''
            function()
              _G.NixvimLoad.plugin("mini.nvim")
              if vim.bo.filetype == "gitcommit" then
                _G.NixvimLoad.plugin("blink-cmp-git")
              end
            end
          '';
          event = [
            "InsertEnter"
            "CmdlineEnter"
          ];
        };
      };
      settings = {
        keymap.preset = "super-tab";
        appearance = {
          nerd_font_variant = "normal";
          use_nvim_cmp_as_default = false;
        };
        completion = {
          accept.auto_brackets.enabled = true;
          documentation = {
            auto_show = true;
            auto_show_delay_ms = 120;
          };
          ghost_text.enabled = true;
          list.selection = {
            preselect = true;
            auto_insert = false;
          };
          menu.border = "rounded";
        };
        signature = {
          enabled = true;
          window.border = "rounded";
        };
        sources = {
          default = [
            "lsp"
            "path"
            "snippets"
            "buffer"
          ];
          per_filetype = {
            toml = [
              "crates"
              "lsp"
              "path"
              "buffer"
            ];
            gitcommit = [
              "git"
              "buffer"
            ];
          };
          providers = {
            git = {
              module = "blink-cmp-git";
              name = "git";
              score_offset = 80;
              opts = {
                commit = {};
                git_centers = {
                  git_hub = {};
                };
              };
            };
          };
        };
        cmdline = {
          enabled = true;
          keymap.preset = "cmdline";
          completion.menu.auto_show = true;
        };
        fuzzy = {
          prebuilt_binaries.download = false;
          sorts = [
            "score"
            "sort_text"
            "label"
          ];
        };
      };
    };

    blink-cmp-git = {
      enable = true;
      lazyLoad = {
        enable = true;
        settings.ft = ["gitcommit"];
      };
    };

    lsp = {
      enable = true;
      lazyLoad = {
        enable = true;
        settings = {
          cmd = [
            "LspInfo"
            "LspLog"
            "LspRestart"
            "LspStart"
            "LspStop"
          ];
          event = [
            "BufReadPre"
            "BufNewFile"
          ];
        };
      };
      keymaps = {
        silent = true;
        lspBuf = {
          K = "hover";
          "<leader>lr" = "rename";
          "<leader>la" = "code_action";
        };
      };
      capabilities = ''
        capabilities.textDocument.completion = capabilities.textDocument.completion or {}
        capabilities.textDocument.completion.completionItem = vim.tbl_deep_extend("force", capabilities.textDocument.completion.completionItem or {}, {
          snippetSupport = true,
          commitCharactersSupport = true,
          deprecatedSupport = true,
          preselectSupport = true,
          tagSupport = { valueSet = { 1 } },
          insertReplaceSupport = true,
          labelDetailsSupport = true,
          resolveSupport = {
            properties = {
              "documentation",
              "detail",
              "additionalTextEdits",
              "sortText",
              "filterText",
              "insertText",
              "textEdit",
              "insertTextFormat",
              "insertTextMode",
            },
          },
          insertTextModeSupport = {
            valueSet = { 1, 2 },
          },
        })
        capabilities.textDocument.completion.completionList = vim.tbl_deep_extend("force", capabilities.textDocument.completion.completionList or {}, {
          itemDefaults = {
            "commitCharacters",
            "editRange",
            "insertTextFormat",
            "insertTextMode",
            "data",
          },
        })
      '';
      servers = {
        nixd = {
          enable = true;
          settings = {
            formatting.command = ["alejandra"];
            nixpkgs.expr = "import <nixpkgs> { }";
            options = {
              nixos.expr = ''(builtins.getFlake "${toString ./../..}").darwinConfigurations.viator.options'';
              home-manager.expr = ''(builtins.getFlake "${toString ./../..}").darwinConfigurations.viator.options.home-manager.users.type.getSubOptions []'';
            };
          };
        };
        lua_ls = {
          enable = true;
          settings = {
            Lua = {
              diagnostics.globals = ["vim"];
              workspace.checkThirdParty = false;
              telemetry.enable = false;
              completion.callSnippet = "Replace";
            };
          };
        };
        taplo.enable = true;
        jsonls.enable = true;
        yamlls.enable = true;
        bashls.enable = true;
        marksman.enable = true;
        clangd.enable = true;
        # rust_analyzer is intentionally owned by rustaceanvim to avoid
        # two clients attaching to every Rust buffer.
      };
    };

    rustaceanvim = {
      enable = true;
      lazyLoad = {
        enable = true;
        settings = {
          cmd = "RustLsp";
          ft = ["rust"];
        };
      };
      settings = {
        tools = {
          enable_nextest = true;
          float_win_config = {
            border = "rounded";
            max_width = 120;
          };
          hover_actions = {
            replace_builtin_hover = true;
            auto_focus = false;
          };
          code_actions.ui_select_fallback = true;
        };
        server = {
          cmd = ["rust-analyzer"];
          standalone = false;
          on_attach = nlib.mkRaw ''
            function(client, bufnr)
              local opts = { buffer = bufnr, silent = true }
              vim.keymap.set("n", "K", function() vim.cmd.RustLsp({ "hover", "actions" }) end, vim.tbl_extend("force", opts, { desc = "Rust Hover Actions" }))
              vim.keymap.set("n", "<leader>la", function() vim.cmd.RustLsp("codeAction") end, vim.tbl_extend("force", opts, { desc = "Rust Code Action" }))
              if client:supports_method("textDocument/codeLens") then
                vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, { buffer = bufnr, callback = vim.lsp.codelens.refresh })
              end
            end
          '';
          default_settings.rust-analyzer = {
            cargo = {
              allFeatures = true;
              buildScripts.enable = true;
              autoreload = true;
              targetDir = true;
            };
            check = {
              command = "clippy";
              allTargets = true;
              features = "all";
            };
            completion = {
              fullFunctionSignatures.enable = true;
              postfix.enable = true;
            };
            diagnostics = {
              experimental.enable = true;
              styleLints.enable = true;
            };
            files.excludeDirs = [
              ".devenv"
              ".direnv"
              ".git"
              "node_modules"
              "result"
              "target"
            ];
            imports = {
              granularity = {
                group = "module";
                enforce = false;
              };
              prefix = "crate";
            };
            lens = {
              enable = true;
              implementations.enable = true;
              references = {
                adt.enable = true;
                enumVariant.enable = true;
                method.enable = true;
                trait.enable = true;
              };
              run.enable = true;
            };
            procMacro = {
              enable = true;
              ignored = {};
            };
            workspace.symbol.search = {
              kind = "all_symbols";
              scope = "workspace_and_dependencies";
            };
            assist.expressionFillDefault = "todo";
            inlayHints = {
              bindingModeHints.enable = false;
              chainingHints.enable = true;
              closingBraceHints.minLines = 25;
              closureCaptureHints.enable = true;
              closureReturnTypeHints.enable = "with_block";
              discriminantHints.enable = "fieldless";
              expressionAdjustmentHints.enable = "reborrow";
              lifetimeElisionHints = {
                enable = "skip_trivial";
                useParameterNames = true;
              };
              rangeExclusiveHints.enable = true;
              typeHints = {
                enable = true;
                hideClosureInitialization = false;
                hideNamedConstructor = false;
              };
            };
          };
        };
      };
    };

    crates = {
      enable = true;
      lazyLoad = {
        enable = true;
        settings = {
          ft = ["toml"];
        };
      };
      settings = {
        smart_insert = true;
        autoload = true;
        autoupdate = true;
        lsp = {
          enabled = true;
          actions = true;
          completion = true;
          hover = true;
        };
        popup = {
          autofocus = true;
          border = "rounded";
          show_version_date = true;
        };
        completion = {
          cmp.enabled = false;
          blink.enabled = true;
          crates = {
            enabled = true;
            max_results = 8;
            min_chars = 3;
          };
        };
      };
    };

    treesitter = {
      enable = true;
      lazyLoad = {
        enable = true;
        settings.event = [
          "BufReadPost"
          "BufNewFile"
        ];
      };
      settings = {
        incremental_selection = {
          enable = true;
          keymaps = {
            init_selection = "<cr>";
            node_incremental = "<cr>";
            scope_incremental = "<tab>";
            node_decremental = "<bs>";
          };
        };
      };
      highlight.enable = true;
      indent.enable = true;
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        bash
        c
        comment
        diff
        dockerfile
        git_config
        git_rebase
        gitcommit
        gitignore
        html
        json
        just
        lua
        luadoc
        make
        markdown
        markdown_inline
        nix
        query
        regex
        ron
        rust
        toml
        vim
        vimdoc
        yaml
      ];
    };

    treesitter-textobjects = {
      enable = true;
      lazyLoad = {
        enable = true;
        settings = {
          before = nlib.mkRaw ''
            function()
              _G.NixvimLoad.plugin("nvim-treesitter")
            end
          '';
          event = [
            "BufReadPost"
            "BufNewFile"
          ];
        };
      };
      settings = {
        select = {
          enable = true;
          lookahead = true;
          keymaps = {
            "af" = "@function.outer";
            "if" = "@function.inner";
            "ac" = "@class.outer";
            "ic" = "@class.inner";
            "aa" = "@parameter.outer";
            "ia" = "@parameter.inner";
          };
        };
        move = {
          enable = true;
          set_jumps = true;
          goto_next_start = {
            "]f" = "@function.outer";
            "]c" = "@class.outer";
          };
          goto_previous_start = {
            "[f" = "@function.outer";
            "[c" = "@class.outer";
          };
        };
      };
    };

    conform-nvim = {
      enable = true;
      autoInstall.enable = true;
      lazyLoad = {
        enable = true;
        settings = {
          event = "BufWritePre";
          cmd = ["ConformInfo"];
        };
      };
      settings = {
        notify_on_error = true;
        notify_no_formatters = false;
        format_on_save = {
          timeout_ms = 1200;
          lsp_format = "fallback";
        };
        formatters_by_ft = {
          nix = ["alejandra"];
          rust = ["rustfmt"];
          lua = ["stylua"];
          toml = ["taplo"];
          "_" = [
            "trim_whitespace"
            "trim_newlines"
          ];
        };
      };
    };

    gitsigns = {
      enable = true;
      lazyLoad = {
        enable = true;
        settings = {
          cmd = "Gitsigns";
          event = [
            "BufReadPost"
            "BufNewFile"
          ];
        };
      };
      settings = {
        current_line_blame = false;
        sign_priority = 6;
        signs = {
          add.text = "▌";
          change.text = "▌";
          delete.text = "▸";
          topdelete.text = "▾";
          changedelete.text = "▌";
          untracked.text = "▌";
        };
      };
    };

    flash = {
      enable = true;
      lazyLoad = {
        enable = true;
        settings = {
          # Flash's setup owns the enhanced f/F/t/T/;/, motions. These key
          # triggers keep the first char motion from falling back to vanilla Vim
          # if it happens before DeferredUIEnter.
          event = "DeferredUIEnter";
          keys = [
            "f"
            "F"
            "t"
            "T"
            ";"
            ","
          ];
        };
      };
      settings = {
        labels = "asdfghjklqwertyuiopzxcvbnm";
        search = {
          mode = "fuzzy";
          multi_window = true;
          wrap = true;
          incremental = true;
        };
        jump = {
          autojump = true;
          jumplist = true;
          nohlsearch = true;
        };
        label = {
          uppercase = false;
          reuse = "lowercase";
          distance = true;
          rainbow = {
            enabled = true;
            shade = 5;
          };
        };
        highlight = {
          backdrop = true;
          matches = true;
          priority = 5000;
        };
        modes = {
          char = {
            enabled = true;
            jump_labels = true;
            multi_line = true;
            autohide = true;
            search.wrap = false;
            highlight.backdrop = true;
            keys = {
              f = "f";
              F = "F";
              t = "t";
              T = "T";
              ";" = ";";
              "," = ",";
            };
          };
          search = {
            enabled = true;
            highlight.backdrop = false;
            jump = {
              history = true;
              register = true;
              nohlsearch = true;
            };
            search = {
              mode = "search";
              incremental = nlib.mkRaw "vim.go.incsearch";
            };
          };
          treesitter = {
            jump.pos = "range";
            label = {
              before = true;
              after = true;
              style = "inline";
            };
            highlight = {
              backdrop = false;
              matches = false;
            };
          };
          treesitter_search = {
            jump.pos = "range";
            remote_op.restore = true;
            label = {
              before = true;
              after = true;
              style = "inline";
            };
          };
          remote.remote_op = {
            restore = true;
            motion = true;
          };
        };
      };
    };

    tiny-inline-diagnostic = {
      enable = true;
      lazyLoad = {
        enable = true;
        settings = {
          # Load before LSP attach so tiny-inline-diagnostic can register its
          # LspAttach hooks instead of racing the first client.
          event = [
            "BufReadPre"
            "BufNewFile"
          ];
          cmd = ["TinyInlineDiag"];
        };
      };
      settings = {
        preset = "modern";
        transparent_bg = true;
        transparent_cursorline = true;
        hi = {
          error = "KodaTinyDiagnosticError";
          warn = "KodaTinyDiagnosticWarn";
          info = "KodaTinyDiagnosticInfo";
          hint = "KodaTinyDiagnosticHint";
          arrow = "KodaTinyDiagnosticArrow";
          background = "KodaTinyDiagnosticBackground";
          mixing_color = "Normal";
        };
        options = {
          show_source = {
            enabled = true;
            if_many = true;
          };
          show_code = true;
          use_icons_from_diagnostic = true;
          set_arrow_to_diag_color = true;
          throttle = 30;
          softwrap = 42;
          add_messages = {
            messages = true;
            display_count = false;
            use_max_severity = true;
            show_multiple_glyphs = true;
          };
          multilines = {
            enabled = true;
            always_show = false;
            trim_whitespaces = true;
            tabstop = 4;
          };
          show_all_diags_on_cursorline = false;
          show_diags_only_under_cursor = false;
          show_related = {
            enabled = true;
            max_count = 3;
          };
          enable_on_insert = false;
          enable_on_select = false;
          overflow = {
            mode = "wrap";
            padding = 4;
          };
          break_line = {
            enabled = false;
            after = 42;
          };
          virt_texts.priority = 4096;
          override_open_float = true;
          experimental.use_window_local_extmarks = false;
        };
      };
    };

    trouble = {
      enable = true;
      lazyLoad = {
        enable = true;
        settings = {
          before = nlib.mkRaw ''
            function()
              _G.NixvimLoad.plugin("mini.nvim")
            end
          '';
          cmd = "Trouble";
        };
      };
      settings = {
        auto_close = true;
        auto_refresh = true;
        focus = true;
        warn_no_results = false;
        open_no_results = true;
      };
    };

    todo-comments = {
      enable = true;
      lazyLoad = {
        enable = true;
        settings = {
          cmd = [
            "TodoTrouble"
            "TodoQuickFix"
            "TodoLocList"
          ];
          event = [
            "BufReadPost"
            "BufNewFile"
          ];
        };
      };
      settings = {
        signs = true;
        highlight = {
          comments_only = true;
          max_line_len = 400;
        };
        search.command = "rg";
      };
    };

    render-markdown = {
      enable = true;
      lazyLoad = {
        enable = true;
        settings = {
          before = nlib.mkRaw ''
            function()
              _G.NixvimLoad.plugin("nvim-treesitter")
            end
          '';
          ft = [
            "markdown"
            "norg"
            "rmd"
            "org"
            "codecompanion"
          ];
        };
      };
      settings = {
        enabled = true;
        max_file_size = 2.0;
        debounce = 80;
        completions.blink.enabled = true;
        code = {
          sign = false;
          width = "block";
          right_pad = 1;
        };
      };
    };

    mini = {
      enable = true;
      mockDevIcons = true;
      lazyLoad = {
        enable = true;
        settings = {
          event = "DeferredUIEnter";
        };
      };
      modules = {
        ai = {
          n_lines = 500;
        };
        icons = {
          style = "glyph";
        };
        pairs = {
          modes = {
            insert = true;
            command = false;
            terminal = false;
          };
        };
        surround = {
          mappings = {
            add = "gsa";
            delete = "gsd";
            find = "gsf";
            find_left = "gsF";
            highlight = "gsh";
            replace = "gsr";
            suffix_last = "l";
            suffix_next = "n";
          };
        };
        comment = {};
        move = {};
        bracketed = {};
        indentscope = {
          symbol = "│";
          options = {
            try_as_border = true;
            border = "both";
          };
        };
        statusline = {
          use_icons = true;
          set_vim_settings = false;
        };
        diff = {
          view.style = "sign";
          source = nlib.mkRaw "require('mini.diff').gen_source.git()";
        };
      };
    };
  };

  extraConfigLuaPre = ''
    _G.NixvimSession = _G.NixvimSession or {}
    _G.NixvimLoad = _G.NixvimLoad or {}
    _G.NixvimSession.focused = true
    _G.NixvimSession.pause_token = 0

    do
      local lz
      local loaded = {}
      local aliases = {
        blink = "blink.cmp",
        blink_git = "blink-cmp-git",
        flash = "flash.nvim",
        mini = "mini.nvim",
        snacks = "snacks.nvim",
        treesitter = "nvim-treesitter",
        trouble = "trouble.nvim",
      }

      local function normalize(name)
        return aliases[name] or name
      end

      function _G.NixvimLoad.plugin(name)
        name = normalize(name)
        if loaded[name] then
          return true
        end
        if not lz then
          local ok, mod = pcall(require, "lz.n")
          if not ok then
            return false
          end
          lz = mod
        end
        local ok = pcall(lz.trigger_load, name)
        if ok then
          loaded[name] = true
        end
        return ok
      end

      function _G.NixvimLoad.plugins(names)
        local ok = true
        for _, name in ipairs(names) do
          ok = _G.NixvimLoad.plugin(name) and ok
        end
        return ok
      end
    end

    function _G.NixvimSession.mark_focused()
      _G.NixvimSession.focused = true
      _G.NixvimSession.pause_token = (_G.NixvimSession.pause_token or 0) + 1
    end

    function _G.NixvimSession.schedule_pause_lsp(opts)
      opts = opts or {}
      _G.NixvimSession.focused = false
      _G.NixvimSession.pause_token = (_G.NixvimSession.pause_token or 0) + 1
      local token = _G.NixvimSession.pause_token
      local delay = opts.delay or 15000
      vim.defer_fn(function()
        if _G.NixvimSession.focused or token ~= _G.NixvimSession.pause_token then
          return
        end
        _G.NixvimSession.pause_lsp(opts)
      end, delay)
    end

    function _G.NixvimSession.has_modified_buffers()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
          return true
        end
      end
      return false
    end

    function _G.NixvimSession.save_persisted()
      _G.NixvimLoad.plugin("persisted.nvim")
      if vim.fn.exists(":Persisted") == 2 then
        pcall(vim.cmd, "silent! Persisted save")
      end
    end

    function _G.NixvimSession.save_all(opts)
      opts = opts or {}
      _G.NixvimSession.save_persisted()
      if vim.env.ZELLIJ ~= nil and vim.fn.executable("zellij") == 1 then
        vim.system({ "zellij", "action", "save-session" }, { detach = true })
      end
      if not opts.quiet then
        vim.notify("Saved Neovim session", vim.log.levels.INFO)
      end
    end

    function _G.NixvimSession.pause_lsp(opts)
      opts = opts or {}
      if #vim.lsp.get_clients() == 0 then
        return
      end
      for _, client in ipairs(vim.lsp.get_clients()) do
        pcall(vim.lsp.stop_client, client.id, true)
      end
      collectgarbage("collect")
      if not opts.quiet then
        vim.notify("Stopped LSP clients", vim.log.levels.INFO)
      end
    end

    function _G.NixvimSession.resume_lsp(opts)
      opts = opts or {}
      if vim.bo.buftype ~= "" or vim.bo.filetype == "" then
        vim.cmd("checktime")
        return
      end
      if opts.only_if_empty and #vim.lsp.get_clients({ bufnr = 0 }) > 0 then
        vim.cmd("checktime")
        return
      end
      vim.cmd("checktime")
      _G.NixvimLoad.plugin("nvim-lspconfig")
      pcall(vim.cmd, "LspStart")
      if vim.bo.filetype == "rust" then
        pcall(function() vim.cmd.RustLsp("restart") end)
      end
      if not opts.quiet then
        vim.notify("Requested LSP restart", vim.log.levels.INFO)
      end
    end

    function _G.NixvimSession.zellij_detach()
      _G.NixvimSession.save_all({ quiet = true })
      _G.NixvimSession.pause_lsp({ quiet = true })
      if vim.env.ZELLIJ == nil or vim.fn.executable("zellij") ~= 1 then
        return vim.notify("Saved session and stopped LSP clients", vim.log.levels.INFO)
      end
      vim.system({ "zellij", "action", "detach" }, { detach = true })
    end

    function _G.NixvimSession.zellij_hibernate()
      pcall(vim.cmd, "silent! wall")
      if _G.NixvimSession.has_modified_buffers() then
        return vim.notify("Write modified buffers before hibernating", vim.log.levels.WARN)
      end
      _G.NixvimSession.save_all({ quiet = true })
      _G.NixvimSession.pause_lsp({ quiet = true })
      if vim.env.ZELLIJ ~= nil and vim.fn.executable("zellij") == 1 then
        vim.system({ "zellij", "action", "detach" }, { detach = true })
        return
      end
      vim.cmd("silent! quitall")
    end


    require("koda").setup({
      transparent = false,
      theme = {
        dark = "dark",
        light = "light",
      },
      -- Koda supplies the efficient base; overrides below make the UI match the
      -- wallpaper while keeping Alabaster's “color only when meaningful” rule.
      auto = false,
      cache = true,
      styles = {
        functions = {},
        keywords = {},
        comments = { italic = true },
        strings = {},
        constants = {},
      },
      on_highlights = function(hl, c)
        local koda = require("koda")
        local wp = {
          bg = "#10161b",
          bg_alt = "#151d23",
          surface = "#202930",
          surface_alt = "#28343c",
          fg = "#d8d6d1",
          white = "#f4ede9",
          muted = "#8f9194",
          subtle = "#596369",
          ink = "#174860",
          red = "#cc4f63",
          red_bright = "#e06b7d",
          rose = "#e7b7b6",
          blue = "#8bb6c8",
          blue_bright = "#a8c9d6",
          gold = "#d4a871",
          cyan = "#79b7c4",
          green = "#92b79c",
        }

        local line = koda.blend(wp.fg, wp.bg, 0.07)
        local select = wp.surface_alt

        -- Core UI: graphite base, minimal accents, no “rainbow by default”.
        hl.Normal = { fg = wp.fg, bg = wp.bg }
        hl.NormalNC = { fg = wp.fg, bg = wp.bg }
        hl.SignColumn = { bg = wp.bg }
        hl.LineNr = { fg = wp.subtle, bg = wp.bg }
        hl.CursorLine = { bg = line }
        hl.CursorLineNr = { fg = wp.rose, bg = line }
        hl.Visual = { bg = select }
        hl.Search = { fg = wp.bg, bg = wp.rose }
        hl.IncSearch = { fg = wp.bg, bg = wp.blue }
        hl.MatchParen = { fg = wp.rose, bg = select, bold = true }
        hl.WinSeparator = { fg = wp.surface_alt, bg = wp.bg }
        hl.FloatBorder = { fg = wp.surface_alt, bg = wp.bg }
        hl.NormalFloat = { fg = wp.fg, bg = wp.bg }
        hl.Pmenu = { fg = wp.fg, bg = wp.bg_alt }
        hl.PmenuSel = { fg = wp.white, bg = select }
        hl.PmenuSbar = { bg = wp.surface }
        hl.PmenuThumb = { bg = wp.subtle }

        -- Alabaster-style syntax: definitions blue, strings/important literals rose,
        -- comments gold; keywords/operators mostly neutral because they are obvious.
        hl.Comment = { fg = wp.gold, italic = true }
        hl.String = { fg = wp.rose }
        hl.Character = { fg = wp.rose }
        hl.Constant = { fg = wp.rose }
        hl.Number = { fg = wp.rose }
        hl.Boolean = { fg = wp.rose }
        hl.Float = { fg = wp.rose }
        hl.Function = { fg = wp.blue }
        hl.Method = { fg = wp.blue }
        hl.Identifier = { fg = wp.fg }
        hl.Statement = { fg = wp.fg }
        hl.Conditional = { fg = wp.fg }
        hl.Repeat = { fg = wp.fg }
        hl.Label = { fg = wp.fg }
        hl.Operator = { fg = wp.muted }
        hl.Keyword = { fg = wp.fg }
        hl.Exception = { fg = wp.fg }
        hl.PreProc = { fg = wp.blue }
        hl.Type = { fg = wp.blue }
        hl.Special = { fg = wp.cyan }
        hl.Delimiter = { fg = wp.muted }

        hl.DiagnosticError = { fg = wp.red_bright }
        hl.DiagnosticWarn = { fg = wp.gold }
        hl.DiagnosticInfo = { fg = wp.blue }
        hl.DiagnosticHint = { fg = wp.green }
        hl.DiagnosticVirtualTextError = { fg = wp.red_bright, bg = "NONE" }
        hl.DiagnosticVirtualTextWarn = { fg = wp.gold, bg = "NONE" }
        hl.DiagnosticVirtualTextInfo = { fg = wp.blue, bg = "NONE" }
        hl.DiagnosticVirtualTextHint = { fg = wp.green, bg = "NONE" }

        -- Plugin surfaces: shared palette across Snacks, Trouble, Mini, Flash, GitSigns.
        hl.SnacksPicker = { fg = wp.fg, bg = wp.bg }
        hl.SnacksPickerBorder = { fg = wp.surface_alt, bg = wp.bg }
        hl.SnacksPickerInputBorder = { fg = wp.rose, bg = wp.bg }
        hl.SnacksPickerMatch = { fg = wp.rose, bold = true }
        hl.SnacksPickerDir = { fg = wp.blue }
        hl.SnacksPickerGitStatusModified = { fg = wp.gold }
        hl.SnacksPickerGitStatusAdded = { fg = wp.green }
        hl.SnacksPickerGitStatusDeleted = { fg = wp.red_bright }
        hl.WhichKey = { fg = wp.rose }
        hl.WhichKeyGroup = { fg = wp.blue }
        hl.WhichKeyDesc = { fg = wp.fg }
        hl.TroubleText = { fg = wp.fg }
        hl.TroubleNormal = { fg = wp.fg, bg = wp.bg }
        hl.FlashLabel = { fg = wp.bg, bg = wp.rose, bold = true }
        hl.FlashMatch = { fg = wp.rose, bg = "NONE" }
        hl.FlashCurrent = { fg = wp.bg, bg = wp.blue, bold = true }
        hl.GitSignsAdd = { fg = wp.green }
        hl.GitSignsChange = { fg = wp.gold }
        hl.GitSignsDelete = { fg = wp.red_bright }
        hl.MiniDiffSignAdd = { fg = wp.green }
        hl.MiniDiffSignChange = { fg = wp.gold }
        hl.MiniDiffSignDelete = { fg = wp.red_bright }
        hl.MiniIconsAzure = { fg = wp.blue }
        hl.MiniIconsBlue = { fg = wp.blue }
        hl.MiniIconsCyan = { fg = wp.cyan }
        hl.MiniIconsGreen = { fg = wp.green }
        hl.MiniIconsGrey = { fg = wp.muted }
        hl.MiniIconsOrange = { fg = wp.gold }
        hl.MiniIconsPurple = { fg = wp.rose }
        hl.MiniIconsRed = { fg = wp.red_bright }
        hl.MiniIconsYellow = { fg = wp.gold }
        hl.RenderMarkdownCode = { bg = wp.bg_alt }
        hl.RenderMarkdownCodeInline = { fg = wp.rose, bg = wp.surface }
        hl.RenderMarkdownH1Bg = { fg = wp.blue, bg = wp.bg }
        hl.RenderMarkdownH2Bg = { fg = wp.rose, bg = wp.bg }

        -- tiny-inline-diagnostic.nvim custom groups.
        hl.KodaTinyDiagnosticError = { fg = wp.red_bright, bg = "NONE" }
        hl.KodaTinyDiagnosticWarn = { fg = wp.gold, bg = "NONE" }
        hl.KodaTinyDiagnosticInfo = { fg = wp.blue, bg = "NONE" }
        hl.KodaTinyDiagnosticHint = { fg = wp.green, bg = "NONE" }
        hl.KodaTinyDiagnosticArrow = { fg = wp.surface_alt, bg = "NONE" }
        hl.KodaTinyDiagnosticBackground = { bg = "NONE" }
      end,
    })

  '';
}
