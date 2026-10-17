# Editing, navigation, treesitter, git signs, sessions and pane movement.
{
  config,
  lib,
  pkgs,
  ...
}: let
  lua = config.lib.nixvim.mkRaw;
  key = lhs: rhs: desc: {
    __unkeyed-1 = lhs;
    __unkeyed-2 = lua rhs;
    inherit desc;
  };
  modeKey = mode: lhs: rhs: desc: key lhs rhs desc // {inherit mode;};

  # smart-splits v3 keeps multiplexer support in separate backend plugins.
  smart-splits-tmux = pkgs.vimUtils.buildVimPlugin {
    pname = "smart-splits-backend-tmux";
    version = "0-unstable-2026-09-22";
    src = pkgs.fetchFromGitHub {
      owner = "smart-splits-nvim";
      repo = "backend-tmux";
      rev = "9e9e6aa9b3eb7a8d3896a993611622ac97abff52";
      hash = "sha256-RcJdM6wFHZOEOK+cXVIT10anktqGgIilPmojFpdY+4g=";
    };
  };

  textobject = lhs: query: {
    mode = ["x" "o"];
    key = lhs;
    action = lua ''function() require("nvim-treesitter-textobjects.select").select_textobject("${query}", "textobjects") end'';
    options.desc = query;
  };
  # ]c/[c keep Vim's diff-hunk meaning inside diff windows.
  move = lhs: fn: query: {
    mode = ["n" "x" "o"];
    key = lhs;
    action = lua ''
      function()
        if vim.wo.diff and ("${lhs}"):find("[cC]") then return vim.cmd.normal({ "${lhs}", bang = true }) end
        require("nvim-treesitter-textobjects.move").${fn}("${query}", "textobjects")
      end
    '';
    options.desc = "${fn} ${query}";
  };
in {
  programs.nixvim = {
    plugins.flash = {
      enable = true;
      lazyLoad.settings.keys = [
        (modeKey ["n" "x" "o"] "s" ''function() require("flash").jump() end'' "Flash")
        (modeKey ["n" "x" "o"] "S" ''function() require("flash").treesitter() end'' "Flash Treesitter")
        (modeKey "o" "r" ''function() require("flash").remote() end'' "Remote Flash")
        (modeKey ["o" "x"] "R" ''function() require("flash").treesitter_search() end'' "Treesitter Search")
        (modeKey "c" "<c-s>" ''function() require("flash").toggle() end'' "Toggle Flash Search")
        (modeKey ["n" "x" "o"] "<c-space>" ''function() require("flash").treesitter({ actions = { ["<c-space>"] = "next", ["<BS>"] = "prev" } }) end'' "Treesitter Incremental Selection")
      ];
    };

    # mini.nvim modules as separate plugins, each loaded when it is needed;
    # icons stay eager because snacks, which-key and bufferline ask for them.
    plugins.mini-icons = {
      enable = true;
      mockDevIcons = true;
    };
    plugins.mini-ai = {
      enable = true;
      settings = {
        n_lines = 500;
        custom_textobjects = {
          o = lua ''
            require("mini.ai").gen_spec.treesitter({
              a = { "@block.outer", "@conditional.outer", "@loop.outer" },
              i = { "@block.inner", "@conditional.inner", "@loop.inner" },
            })
          '';
          t = ["<([%p%w]-)%f[^<%w][^<>]->.-</%1>" "^<.->().*()</[^/]->$"];
          d = ["%f[%d]%d+"];
          u = lua ''require("mini.ai").gen_spec.function_call()'';
          U = lua ''require("mini.ai").gen_spec.function_call({ name_pattern = "[%w_]" })'';
          g = lua ''
            function(ai_type)
              local first, last = 1, vim.fn.line("$")
              if ai_type == "i" then
                first, last = vim.fn.nextnonblank(first), vim.fn.prevnonblank(last)
                if first == 0 or last == 0 then return { from = { line = 1, col = 1 } } end
              end
              return { from = { line = first, col = 1 }, to = { line = last, col = math.max(vim.fn.getline(last):len(), 1) } }
            end
          '';
        };
      };
      lazyLoad.settings.event = "DeferredUIEnter";
    };
    plugins.mini-surround = {
      enable = true;
      settings.mappings = {
        add = "gsa";
        delete = "gsd";
        find = "gsf";
        find_left = "gsF";
        highlight = "gsh";
        replace = "gsr";
        update_n_lines = "gsn";
      };
      lazyLoad.settings.keys = [
        {
          __unkeyed-1 = "gsa";
          mode = ["n" "x"];
          desc = "Add Surrounding";
        }
        {
          __unkeyed-1 = "gsd";
          desc = "Delete Surrounding";
        }
        {
          __unkeyed-1 = "gsf";
          desc = "Find Right Surrounding";
        }
        {
          __unkeyed-1 = "gsF";
          desc = "Find Left Surrounding";
        }
        {
          __unkeyed-1 = "gsh";
          desc = "Highlight Surrounding";
        }
        {
          __unkeyed-1 = "gsr";
          desc = "Replace Surrounding";
        }
        {
          __unkeyed-1 = "gsn";
          desc = "Update MiniSurround.config.n_lines";
        }
      ];
    };
    plugins.mini-pairs = {
      enable = true;
      settings.modes = {
        insert = true;
        command = true;
        terminal = false;
      };
      lazyLoad.settings.event = ["InsertEnter" "CmdlineEnter"];
    };
    # Alt-h/j/k/l resize splits in Normal mode (smart-splits), so mini.move
    # only moves Visual selections.
    plugins.mini-move = {
      enable = true;
      settings.mappings = {
        left = "<M-h>";
        right = "<M-l>";
        down = "<M-j>";
        up = "<M-k>";
        line_left = "";
        line_right = "";
        line_down = "";
        line_up = "";
      };
      lazyLoad.settings.keys = map (lhs: {
        __unkeyed-1 = lhs;
        mode = "x";
      }) ["<M-h>" "<M-j>" "<M-k>" "<M-l>"];
    };
    plugins.mini-hipatterns = {
      enable = true;
      settings.highlighters.hex_color = lua ''require("mini.hipatterns").gen_highlighter.hex_color()'';
      lazyLoad.settings.event = ["BufReadPost" "BufNewFile"];
    };

    plugins.yanky = {
      enable = true;
      settings = {
        system_clipboard.sync_with_ring = lua "not vim.env.SSH_CONNECTION";
        highlight = {
          on_yank = false; # the core TextYankPost autocmd already flashes yanks
          timer = 150;
        };
      };
      lazyLoad.settings.keys = [
        (modeKey ["n" "x"] "<leader>p" "function() Snacks.picker.yanky() end" "Open Yank History")
        {
          __unkeyed-1 = "y";
          __unkeyed-2 = "<Plug>(YankyYank)";
          mode = ["n" "x"];
          desc = "Yank Text";
        }
        {
          __unkeyed-1 = "p";
          __unkeyed-2 = "<Plug>(YankyPutAfter)";
          mode = ["n" "x"];
          desc = "Put Text After Cursor";
        }
        {
          __unkeyed-1 = "P";
          __unkeyed-2 = "<Plug>(YankyPutBefore)";
          mode = ["n" "x"];
          desc = "Put Text Before Cursor";
        }
        {
          __unkeyed-1 = "gp";
          __unkeyed-2 = "<Plug>(YankyGPutAfter)";
          mode = ["n" "x"];
          desc = "Put Text After Selection";
        }
        {
          __unkeyed-1 = "gP";
          __unkeyed-2 = "<Plug>(YankyGPutBefore)";
          mode = ["n" "x"];
          desc = "Put Text Before Selection";
        }
        {
          __unkeyed-1 = "[y";
          __unkeyed-2 = "<Plug>(YankyCycleForward)";
          mode = "n";
          desc = "Cycle Forward Through Yank History";
        }
        {
          __unkeyed-1 = "]y";
          __unkeyed-2 = "<Plug>(YankyCycleBackward)";
          mode = "n";
          desc = "Cycle Backward Through Yank History";
        }
        {
          __unkeyed-1 = "]p";
          __unkeyed-2 = "<Plug>(YankyPutIndentAfterLinewise)";
          mode = "n";
          desc = "Put Indented After Cursor (Linewise)";
        }
        {
          __unkeyed-1 = "[p";
          __unkeyed-2 = "<Plug>(YankyPutIndentBeforeLinewise)";
          mode = "n";
          desc = "Put Indented Before Cursor (Linewise)";
        }
        {
          __unkeyed-1 = ">p";
          __unkeyed-2 = "<Plug>(YankyPutIndentAfterShiftRight)";
          mode = "n";
          desc = "Put and Indent Right";
        }
        {
          __unkeyed-1 = "<p";
          __unkeyed-2 = "<Plug>(YankyPutIndentAfterShiftLeft)";
          mode = "n";
          desc = "Put and Indent Left";
        }
        {
          __unkeyed-1 = "=p";
          __unkeyed-2 = "<Plug>(YankyPutAfterFilter)";
          mode = "n";
          desc = "Put After Applying a Filter";
        }
      ];
    };

    plugins.inc-rename.enable = true;

    plugins.dial = {
      enable = true;
      lazyLoad.settings = {
        keys = let
          dial = mode: dir: g: lhs:
            modeKey mode lhs ''function() require("dial.map").manipulate("${dir}", "${g}${
                if mode == "n"
                then "normal"
                else "visual"
              }") end'' "${dir}";
        in [
          (dial "n" "increment" "" "<C-a>")
          (dial "n" "decrement" "" "<C-x>")
          (dial "x" "increment" "" "<C-a>")
          (dial "x" "decrement" "" "<C-x>")
          (dial "n" "increment" "g" "g<C-a>")
          (dial "n" "decrement" "g" "g<C-x>")
          (dial "x" "increment" "g" "g<C-a>")
          (dial "x" "decrement" "g" "g<C-x>")
        ];
        after = lua ''
          function()
            local augend = require("dial.augend")
            require("dial.config").augends:register_group({
              default = {
                augend.integer.alias.decimal_int,
                augend.integer.alias.hex,
                augend.date.alias["%Y-%m-%d"],
                augend.constant.alias.bool,
                augend.semver.alias.semver,
                augend.constant.new({ elements = { "&&", "||" }, word = false, cyclic = true }),
                augend.constant.new({ elements = { "let", "const" } }),
                augend.constant.new({ elements = { "True", "False" } }),
              },
            })
          end
        '';
      };
    };

    plugins.harpoon = {
      enable = true;
      settings.settings.save_on_toggle = true;
      lazyLoad.settings.keys =
        [
          (key "<leader>H" ''function() require("harpoon"):list():add() end'' "Harpoon File")
          (key "<leader>h" ''function() local h = require("harpoon"); h.ui:toggle_quick_menu(h:list()) end'' "Harpoon Quick Menu")
        ]
        ++ map (i: key "<leader>${toString i}" ''function() require("harpoon"):list():select(${toString i}) end'' "Harpoon to File ${toString i}") (lib.range 1 9);
    };

    plugins.treesitter = {
      enable = true;
      highlight.enable = true;
      # Indentation is set below: the module's check parses each language's
      # indents query on every first open, which is most of the open cost
      # after highlighting.
      indent.enable = false;
      folding.enable = true;
      grammarPackages = map (name: config.programs.nixvim.plugins.treesitter.package.builtGrammars.${name}) [
        "astro"
        "bash"
        "c"
        "cmake"
        "cpp"
        "css"
        "diff"
        "fish"
        "git_rebase"
        "gitcommit"
        "gitignore"
        "html"
        "javascript"
        "jsdoc"
        "json"
        "json5"
        "lua"
        "luadoc"
        "luap"
        "make"
        "markdown"
        "markdown_inline"
        "nix"
        "printf"
        "python"
        "query"
        "regex"
        "ron"
        "rust"
        "scss"
        "svelte"
        "toml"
        "tsx"
        "typescript"
        "vim"
        "vimdoc"
        "xml"
        "yaml"
      ];
    };
    autoCmd = [
      {
        event = "FileType";
        group = "core";
        desc = "Tree-sitter indentation where the language has an indents query";
        callback = lua ''
          function(ev)
            local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
            if lang and #vim.treesitter.query.get_files(lang, "indents") > 0 then
              vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
          end
        '';
      }
    ];
    plugins.treesitter-textobjects.enable = true;
    plugins.treesitter-context = {
      enable = true;
      settings = {
        max_lines = 3;
        multiline_threshold = 1;
      };
      lazyLoad.settings.event = ["BufReadPost" "BufNewFile"];
    };
    plugins.ts-autotag = {
      enable = true;
      lazyLoad.settings.event = ["BufReadPre" "BufNewFile"];
    };
    plugins.ts-comments = {
      enable = true;
      lazyLoad.settings.event = "DeferredUIEnter";
    };
    extraConfigLua = ''
      require("nvim-treesitter-textobjects").setup({ select = { lookahead = true }, move = { set_jumps = true } })
    '';

    plugins.todo-comments = {
      enable = true;
      lazyLoad.settings = {
        event = ["BufReadPost" "BufNewFile"];
        keys = [
          (key "]t" ''function() require("todo-comments").jump_next() end'' "Next Todo Comment")
          (key "[t" ''function() require("todo-comments").jump_prev() end'' "Previous Todo Comment")
          (key "<leader>st" "function() Snacks.picker.todo_comments() end" "Todo")
          (key "<leader>sT" ''function() Snacks.picker.todo_comments({ keywords = { "TODO", "FIX", "FIXME" } }) end'' "Todo/Fix/Fixme")
          {
            __unkeyed-1 = "<leader>xt";
            __unkeyed-2 = "<cmd>Trouble todo toggle<cr>";
            desc = "Todo (Trouble)";
          }
          {
            __unkeyed-1 = "<leader>xT";
            __unkeyed-2 = "<cmd>Trouble todo toggle filter = {tag = {TODO,FIX,FIXME}}<cr>";
            desc = "Todo/Fix/Fixme (Trouble)";
          }
        ];
      };
    };

    plugins.trouble = {
      enable = true;
      settings.modes.lsp.win.position = "right";
      lazyLoad.settings.cmd = "Trouble";
    };

    plugins.grug-far = {
      enable = true;
      settings.headerMaxWidth = 80;
      lazyLoad.settings = {
        cmd = ["GrugFar" "GrugFarWithin"];
        keys = [
          (modeKey ["n" "x"] "<leader>sr" ''
              function()
                local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
                require("grug-far").open({ transient = true, prefills = { filesFilter = ext and ext ~= "" and "*." .. ext or nil } })
              end
            ''
            "Search and Replace")
        ];
      };
    };

    plugins.persistence = {
      enable = true;
      lazyLoad.settings = {
        event = "BufReadPre";
        keys = [
          (key "<leader>qs" ''function() require("persistence").load() end'' "Restore Session")
          (key "<leader>qS" ''function() require("persistence").select() end'' "Select Session")
          (key "<leader>ql" ''function() require("persistence").load({ last = true }) end'' "Restore Last Session")
          (key "<leader>qd" ''function() require("persistence").stop() end'' "Don't Save Current Session")
        ];
      };
    };

    # C-h/j/k/l cross Neovim splits, then tmux panes (the backend sets the
    # pane's @pane-is-vim, which tmux's root bindings test). Loading after the
    # first frame keeps tmux's synchronous handshake off the startup path.
    plugins.smart-splits = {
      enable = true;
      settings = {
        mux.backend = "smart-splits-backend-tmux";
        move.at_edge = "stop";
      };
      lazyLoad.settings = {
        event = "DeferredUIEnter";
        keys = [
          (key "<C-h>" ''function() require("smart-splits").move_cursor_left() end'' "Go to Left Window")
          (key "<C-j>" ''function() require("smart-splits").move_cursor_down() end'' "Go to Lower Window")
          (key "<C-k>" ''function() require("smart-splits").move_cursor_up() end'' "Go to Upper Window")
          (key "<C-l>" ''function() require("smart-splits").move_cursor_right() end'' "Go to Right Window")
          (key "<A-h>" ''function() require("smart-splits").resize_left() end'' "Resize Left")
          (key "<A-j>" ''function() require("smart-splits").resize_down() end'' "Resize Down")
          (key "<A-k>" ''function() require("smart-splits").resize_up() end'' "Resize Up")
          (key "<A-l>" ''function() require("smart-splits").resize_right() end'' "Resize Right")
        ];
      };
    };

    plugins.gitsigns = {
      enable = true;
      lazyLoad.settings.event = ["BufReadPre" "BufNewFile"];
      settings = {
        signs = {
          add.text = "▎";
          change.text = "▎";
          delete.text = "";
          topdelete.text = "";
          changedelete.text = "▎";
          untracked.text = "▎";
        };
        signs_staged = {
          add.text = "▎";
          change.text = "▎";
          delete.text = "";
          topdelete.text = "";
          changedelete.text = "▎";
        };
        on_attach = lua ''
          function(buf)
            local gs = package.loaded.gitsigns
            local function map(mode, l, r, desc) vim.keymap.set(mode, l, r, { buffer = buf, desc = desc, silent = true }) end
            map("n", "]h", function() if vim.wo.diff then vim.cmd.normal({ "]c", bang = true }) else gs.nav_hunk("next") end end, "Next Hunk")
            map("n", "[h", function() if vim.wo.diff then vim.cmd.normal({ "[c", bang = true }) else gs.nav_hunk("prev") end end, "Prev Hunk")
            map("n", "]H", function() gs.nav_hunk("last") end, "Last Hunk")
            map("n", "[H", function() gs.nav_hunk("first") end, "First Hunk")
            map({ "n", "x" }, "<leader>ghs", ":Gitsigns stage_hunk<CR>", "Stage Hunk")
            map({ "n", "x" }, "<leader>ghr", ":Gitsigns reset_hunk<CR>", "Reset Hunk")
            map("n", "<leader>ghS", gs.stage_buffer, "Stage Buffer")
            map("n", "<leader>ghu", gs.undo_stage_hunk, "Undo Stage Hunk")
            map("n", "<leader>ghR", gs.reset_buffer, "Reset Buffer")
            map("n", "<leader>ghp", gs.preview_hunk_inline, "Preview Hunk Inline")
            map("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, "Blame Line")
            map("n", "<leader>ghB", function() gs.blame() end, "Blame Buffer")
            map("n", "<leader>ghd", gs.diffthis, "Diff This")
            map("n", "<leader>ghD", function() gs.diffthis("~") end, "Diff This ~")
            map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "GitSigns Select Hunk")
          end
        '';
      };
    };

    plugins.render-markdown = {
      enable = true;
      settings = {
        code = {
          sign = false;
          width = "block";
          right_pad = 1;
        };
        heading = {
          sign = false;
          icons = [];
        };
        checkbox.enabled = false;
      };
      lazyLoad.settings.ft = "markdown";
    };

    extraPlugins = [smart-splits-tmux];

    keymaps =
      lib.mapAttrsToList textobject {
        af = "@function.outer";
        "if" = "@function.inner";
        ac = "@class.outer";
        ic = "@class.inner";
        aa = "@parameter.outer";
        ia = "@parameter.inner";
      }
      ++ [
        (move "]f" "goto_next_start" "@function.outer")
        (move "]c" "goto_next_start" "@class.outer")
        (move "]a" "goto_next_start" "@parameter.inner")
        (move "]F" "goto_next_end" "@function.outer")
        (move "]C" "goto_next_end" "@class.outer")
        (move "]A" "goto_next_end" "@parameter.inner")
        (move "[f" "goto_previous_start" "@function.outer")
        (move "[c" "goto_previous_start" "@class.outer")
        (move "[a" "goto_previous_start" "@parameter.inner")
        (move "[F" "goto_previous_end" "@function.outer")
        (move "[C" "goto_previous_end" "@class.outer")
        (move "[A" "goto_previous_end" "@parameter.inner")
      ]
      ++ [
        # Trouble.
        {
          mode = "n";
          key = "<leader>xx";
          action = "<cmd>Trouble diagnostics toggle<cr>";
          options.desc = "Diagnostics (Trouble)";
        }
        {
          mode = "n";
          key = "<leader>xX";
          action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>";
          options.desc = "Buffer Diagnostics (Trouble)";
        }
        {
          mode = "n";
          key = "<leader>cs";
          action = "<cmd>Trouble symbols toggle<cr>";
          options.desc = "Symbols (Trouble)";
        }
        {
          mode = "n";
          key = "<leader>cS";
          action = "<cmd>Trouble lsp toggle<cr>";
          options.desc = "LSP references/definitions/... (Trouble)";
        }
        {
          mode = "n";
          key = "<leader>xL";
          action = "<cmd>Trouble loclist toggle<cr>";
          options.desc = "Location List (Trouble)";
        }
        {
          mode = "n";
          key = "<leader>xQ";
          action = "<cmd>Trouble qflist toggle<cr>";
          options.desc = "Quickfix List (Trouble)";
        }
        {
          mode = "n";
          key = "<leader>um";
          action = lua ''function() require("lz.n").trigger_load("render-markdown.nvim"); require("render-markdown").toggle() end'';
          options.desc = "Toggle Markdown Rendering";
        }
      ];
  };
}
