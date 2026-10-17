# Options, core keymaps and autocommands: LazyVim's defaults plus the
# baseline's own tweaks (rounded borders, scrolloff 8, linebreak).
{config, ...}: let
  map = mode: key: action: desc: {
    inherit mode key action;
    options = {inherit desc;};
  };
  lua = config.lib.nixvim.mkRaw;
  # Jump to the next/previous diagnostic, optionally of one severity.
  jump = count: severity:
    lua "function() vim.diagnostic.jump({ count = ${toString count} * vim.v.count1, severity = ${
      if severity == null
      then "nil"
      else "vim.diagnostic.severity.${severity}"
    }, float = true }) end";
in {
  programs.nixvim = {
    globals = {
      mapleader = " ";
      maplocalleader = ",";
      # Unused runtime plugins; the snacks explorer stands in for netrw.
      loaded_netrw = 1;
      loaded_netrwPlugin = 1;
      loaded_gzip = 1;
      loaded_tarPlugin = 1;
      loaded_zipPlugin = 1;
      loaded_2html_plugin = 1;
      loaded_tutor_mode_plugin = 1;
    };

    opts = {
      autowrite = true;
      # OSC 52 handles the clipboard over SSH.
      clipboard = lua ''vim.env.SSH_CONNECTION and "" or "unnamedplus"'';
      completeopt = "menu,menuone,noselect";
      conceallevel = 2;
      confirm = true;
      cursorline = true;
      expandtab = true;
      # Repos may carry a .nvim.lua; Neovim asks before trusting each one.
      exrc = true;
      fillchars = {
        foldopen = "";
        foldclose = "";
        fold = " ";
        foldsep = " ";
        diff = " ";
        eob = " ";
      };
      foldlevel = 99;
      foldmethod = "indent";
      foldtext = "";
      formatoptions = "jcroqlnt";
      grepformat = "%f:%l:%c:%m";
      grepprg = "rg --vimgrep";
      ignorecase = true;
      inccommand = "nosplit";
      jumpoptions = "view";
      laststatus = 3;
      linebreak = true;
      list = true;
      mouse = "a";
      number = true;
      pumblend = 10;
      pumheight = 10;
      relativenumber = true;
      ruler = false;
      scrolloff = 8;
      sessionoptions = ["buffers" "curdir" "tabpages" "winsize" "help" "globals" "skiprtp" "folds"];
      shiftround = true;
      shiftwidth = 2;
      shortmess = "ltToOCFWIc";
      showmode = false;
      sidescrolloff = 8;
      signcolumn = "yes";
      smartcase = true;
      smartindent = true;
      smoothscroll = true;
      spelllang = ["en"];
      splitbelow = true;
      splitkeep = "screen";
      splitright = true;
      tabstop = 2;
      termguicolors = true;
      timeoutlen = 300;
      undofile = true;
      undolevels = 10000;
      updatetime = 200;
      virtualedit = "block";
      wildmode = "longest:full,full";
      winborder = "rounded";
      winminwidth = 5;
      wrap = false;
    };

    filetype.filename.".clangd" = "yaml";

    diagnostic.settings = {
      underline = true;
      update_in_insert = false;
      severity_sort = true;
      virtual_text = {
        spacing = 4;
        source = "if_many";
        prefix = "●";
      };
      float = {
        border = "rounded";
        source = "if_many";
      };
      signs.text = lua ''
        {
          [vim.diagnostic.severity.ERROR] = " ",
          [vim.diagnostic.severity.WARN] = " ",
          [vim.diagnostic.severity.HINT] = " ",
          [vim.diagnostic.severity.INFO] = " ",
        }
      '';
    };

    autoGroups.core.clear = true;
    autoCmd = [
      {
        event = ["FocusGained" "TermClose" "TermLeave"];
        group = "core";
        desc = "Reload files changed outside Neovim";
        callback = lua ''function() if vim.o.buftype ~= "nofile" then vim.cmd("checktime") end end'';
      }
      {
        event = "TextYankPost";
        group = "core";
        callback = lua "function() (vim.hl or vim.highlight).on_yank() end";
      }
      {
        event = "VimResized";
        group = "core";
        desc = "Equalise splits on resize";
        callback = lua ''function() local tab = vim.fn.tabpagenr(); vim.cmd("tabdo wincmd ="); vim.cmd("tabnext " .. tab) end'';
      }
      {
        event = "BufReadPost";
        group = "core";
        desc = "Return to the last edit position";
        callback = lua ''
          function(ev)
            -- Filetype detection runs after this group, so match it here.
            local exclude = { gitcommit = true, gitrebase = true }
            if exclude[vim.filetype.match({ buf = ev.buf }) or ""] or vim.b[ev.buf].core_last_loc then return end
            vim.b[ev.buf].core_last_loc = true
            local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
            if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
              pcall(vim.api.nvim_win_set_cursor, 0, mark)
            end
          end
        '';
      }
      {
        event = "FileType";
        group = "core";
        pattern = ["checkhealth" "grug-far" "help" "lspinfo" "notify" "qf" "startuptime" "gitsigns-blame" "dap-float" "neotest-output" "neotest-output-panel" "neotest-summary"];
        desc = "Close utility windows with q";
        callback = lua ''
          function(ev)
            vim.bo[ev.buf].buflisted = false
            vim.keymap.set("n", "q", function() pcall(vim.cmd.close); pcall(vim.api.nvim_buf_delete, ev.buf, { force = true }) end,
              { buffer = ev.buf, silent = true, desc = "Quit buffer" })
          end
        '';
      }
      {
        event = "FileType";
        group = "core";
        pattern = ["text" "plaintex" "typst" "gitcommit" "markdown"];
        callback = lua "function() vim.opt_local.wrap = true; vim.opt_local.spell = true end";
      }
      {
        event = "FileType";
        group = "core";
        pattern = ["c" "cpp" "objc" "objcpp" "cuda"];
        desc = "4-space indent for the C family";
        callback = lua "function() vim.bo.shiftwidth = 4; vim.bo.tabstop = 4; vim.bo.softtabstop = 4 end";
      }
      {
        event = "FileType";
        group = "core";
        pattern = ["json" "jsonc" "json5"];
        callback = lua "function() vim.opt_local.conceallevel = 0 end";
      }
      {
        event = "BufWritePre";
        group = "core";
        desc = "Create missing parent directories on save";
        callback = lua ''
          function(ev)
            if ev.match:match("^%w%w+:[\\/][\\/]") then return end
            vim.fn.mkdir(vim.fn.fnamemodify(vim.uv.fs_realpath(ev.match) or ev.match, ":p:h"), "p")
          end
        '';
      }
    ];

    keymaps = [
      # Display-line motion without a count.
      {
        mode = ["n" "x"];
        key = "j";
        action = "v:count == 0 ? 'gj' : 'j'";
        options = {
          expr = true;
          silent = true;
        };
      }
      {
        mode = ["n" "x"];
        key = "k";
        action = "v:count == 0 ? 'gk' : 'k'";
        options = {
          expr = true;
          silent = true;
        };
      }
      (map "n" "<C-Up>" "<cmd>resize +2<cr>" "Increase Window Height")
      (map "n" "<C-Down>" "<cmd>resize -2<cr>" "Decrease Window Height")
      (map "n" "<C-Left>" "<cmd>vertical resize -2<cr>" "Decrease Window Width")
      (map "n" "<C-Right>" "<cmd>vertical resize +2<cr>" "Increase Window Width")
      (map "n" "<leader>bb" "<cmd>e #<cr>" "Switch to Other Buffer")
      (map "n" "<leader>`" "<cmd>e #<cr>" "Switch to Other Buffer")
      {
        mode = ["i" "n" "s"];
        key = "<esc>";
        action = lua ''function() vim.cmd("noh"); if vim.snippet then vim.snippet.stop() end; return "<esc>" end'';
        options = {
          expr = true;
          desc = "Escape and Clear hlsearch";
        };
      }
      (map "n" "<leader>ur" "<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>" "Redraw / Clear hlsearch / Diff Update")
      {
        mode = "n";
        key = "n";
        action = "'Nn'[v:searchforward].'zv'";
        options = {
          expr = true;
          desc = "Next Search Result";
        };
      }
      {
        mode = ["x" "o"];
        key = "n";
        action = "'Nn'[v:searchforward]";
        options = {
          expr = true;
          desc = "Next Search Result";
        };
      }
      {
        mode = "n";
        key = "N";
        action = "'nN'[v:searchforward].'zv'";
        options = {
          expr = true;
          desc = "Prev Search Result";
        };
      }
      {
        mode = ["x" "o"];
        key = "N";
        action = "'nN'[v:searchforward]";
        options = {
          expr = true;
          desc = "Prev Search Result";
        };
      }
      # Undo break-points.
      (map "i" "," ",<c-g>u" null)
      (map "i" "." ".<c-g>u" null)
      (map "i" ";" ";<c-g>u" null)
      (map ["i" "x" "n" "s"] "<C-s>" "<cmd>w<cr><esc>" "Save File")
      (map "n" "<leader>K" "<cmd>norm! K<cr>" "Keywordprg")
      (map "x" "<" "<gv" null)
      (map "x" ">" ">gv" null)
      (map "n" "gco" "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>" "Add Comment Below")
      (map "n" "gcO" "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>" "Add Comment Above")
      (map "n" "<leader>fn" "<cmd>enew<cr>" "New File")
      (map "n" "<leader>xl" (lua ''
        function()
          local ok, err = pcall(vim.fn.getloclist(0, { winid = 0 }).winid ~= 0 and vim.cmd.lclose or vim.cmd.lopen)
          if not ok and err then vim.notify(err, vim.log.levels.ERROR) end
        end
      '') "Location List")
      (map "n" "<leader>xq" (lua ''
        function()
          local ok, err = pcall(vim.fn.getqflist({ winid = 0 }).winid ~= 0 and vim.cmd.cclose or vim.cmd.copen)
          if not ok and err then vim.notify(err, vim.log.levels.ERROR) end
        end
      '') "Quickfix List")
      (map "n" "[q" (lua "vim.cmd.cprev") "Previous Quickfix")
      (map "n" "]q" (lua "vim.cmd.cnext") "Next Quickfix")
      (map "n" "<leader>cd" (lua "vim.diagnostic.open_float") "Line Diagnostics")
      (map "n" "]d" (jump 1 null) "Next Diagnostic")
      (map "n" "[d" (jump (-1) null) "Prev Diagnostic")
      (map "n" "]e" (jump 1 "ERROR") "Next Error")
      (map "n" "[e" (jump (-1) "ERROR") "Prev Error")
      (map "n" "]w" (jump 1 "WARN") "Next Warning")
      (map "n" "[w" (jump (-1) "WARN") "Prev Warning")
      (map "n" "<leader>qq" "<cmd>qa<cr>" "Quit All")
      (map "n" "<leader>ui" (lua "vim.show_pos") "Inspect Pos")
      (map "n" "<leader>uI" (lua ''function() vim.treesitter.inspect_tree(); vim.api.nvim_input("I") end'') "Inspect Tree")
      # Windows and tabs.
      {
        mode = "n";
        key = "<leader>-";
        action = "<C-W>s";
        options = {
          remap = true;
          desc = "Split Window Below";
        };
      }
      {
        mode = "n";
        key = "<leader>|";
        action = "<C-W>v";
        options = {
          remap = true;
          desc = "Split Window Right";
        };
      }
      {
        mode = "n";
        key = "<leader>wd";
        action = "<C-W>c";
        options = {
          remap = true;
          desc = "Delete Window";
        };
      }
      (map "n" "<leader><tab>l" "<cmd>tablast<cr>" "Last Tab")
      (map "n" "<leader><tab>o" "<cmd>tabonly<cr>" "Close Other Tabs")
      (map "n" "<leader><tab>f" "<cmd>tabfirst<cr>" "First Tab")
      (map "n" "<leader><tab><tab>" "<cmd>tabnew<cr>" "New Tab")
      (map "n" "<leader><tab>]" "<cmd>tabnext<cr>" "Next Tab")
      (map "n" "<leader><tab>d" "<cmd>tabclose<cr>" "Close Tab")
      (map "n" "<leader><tab>[" "<cmd>tabprevious<cr>" "Previous Tab")
    ];
  };
}
