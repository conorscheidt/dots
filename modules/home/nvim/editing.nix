# Editing, navigation, treesitter, git signs, sessions and pane movement.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.lib.nixvim) mkRaw;
  key = lhs: rhs: desc: {
    __unkeyed-1 = lhs;
    __unkeyed-2 = mkRaw rhs;
    inherit desc;
  };
  modeKey =
    mode: lhs: rhs: desc:
    key lhs rhs desc // { inherit mode; };
  splitKey = lhs: method: key lhs ''function() require("smart-splits").${method}() end'';

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

  # ]c/[c keep Vim's diff-hunk meaning inside diff windows.
  move = lhs: fn: query: desc: {
    mode = [
      "n"
      "x"
      "o"
    ];
    key = lhs;
    action = mkRaw ''
      function()
        if vim.wo.diff and ("${lhs}"):find("[cC]") then return vim.cmd.normal({ "${lhs}", bang = true }) end
        -- Buffers without a parser (TeX) would raise E5108.
        if not vim.treesitter.get_parser(nil, nil, { error = false }) then return end
        require("nvim-treesitter-textobjects.move").${fn}("${query}", "textobjects")
      end
    '';
    options.desc = desc;
  };
in
{
  programs.nixvim = {
    plugins.flash = {
      enable = true;
      # Loaded after the first frame rather than on the first jump, so f/t/;/,
      # are flash's char mode all session instead of switching midway.
      lazyLoad.settings.event = "DeferredUIEnter";
      lazyLoad.settings.keys = [
        (modeKey [ "n" "x" "o" ] "s" ''function() require("flash").jump() end'' "Flash")
        (modeKey [ "n" "x" "o" ] "S" ''function() require("flash").treesitter() end'' "Flash Treesitter")
        (modeKey "o" "r" ''function() require("flash").remote() end'' "Remote Flash")
        (modeKey [
          "o"
          "x"
        ] "R" ''function() require("flash").treesitter_search() end'' "Treesitter Search")
        (modeKey "c" "<c-s>" ''function() require("flash").toggle() end'' "Toggle Flash Search")
      ];
    };

    # mini.nvim modules as separate plugins, each loaded when it is needed;
    # icons stay eager because snacks and which-key ask for them.
    plugins.mini-icons = {
      enable = true;
      mockDevIcons = true;
    };
    plugins.mini-ai = {
      enable = true;
      settings = {
        n_lines = 500;
        # Visual an/in stay Neovim's (treesitter node / LSP selectionRange).
        mappings = {
          around_next = "aN";
          inside_next = "iN";
          around_last = "aL";
          inside_last = "iL";
        };
        # Tree-sitter functions and classes as mini.ai objects, so counts and
        # next/last (aNf, iLc) work for them too; tree-sitter-textobjects
        # only moves.
        custom_textobjects = {
          f = mkRaw ''require("mini.ai").gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" })'';
          c = mkRaw ''require("mini.ai").gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" })'';
          o = mkRaw ''
            require("mini.ai").gen_spec.treesitter({
              a = { "@block.outer", "@conditional.outer", "@loop.outer" },
              i = { "@block.inner", "@conditional.inner", "@loop.inner" },
            })
          '';
          t = [
            "<([%p%w]-)%f[^<%w][^<>]->.-</%1>"
            "^<.->().*()</[^/]->$"
          ];
          d = [ "%f[%d]%d+" ];
          u = mkRaw ''require("mini.ai").gen_spec.function_call()'';
          U = mkRaw ''require("mini.ai").gen_spec.function_call({ name_pattern = "[%w_]" })'';
          g = mkRaw ''
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
          mode = [
            "n"
            "x"
          ];
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
    # Insert-mode autopairs that reuse an unmatched closer (`foo|)` + `(`
    # gives `foo(|)`), from an indent-aware parser that also marks unmatched
    # delimiters. Loaded with the first buffer so those marks are there in
    # Normal mode before any typing. Its parser lacks HTML, CSS, YAML and
    # Astro, so the builtin matchparen stays. The cmdline is left alone: 0.7.1
    # judges it by the current buffer's parse state.
    plugins.blink-pairs = {
      enable = true;
      settings = {
        mappings = {
          cmdline = false;
          pairs =
            let
              # Close a pair only where nothing but whitespace, a closer or a
              # separator follows; before text you are wrapping it, so
              # `|Reverse<u64>` + `(` stays `(Reverse<u64>`. No padding: a space
              # typed inside `{|}` is yours, so `{ a }` types as `{ a }`.
              free = ''
                function(ctx)
                  local next = ctx:text_after_cursor(1)
                  return next == "" or next:match("[%s%)%]%}>,;]") ~= nil
                end
              '';
              bracket = open: close: {
                __unkeyed-1 = open;
                __unkeyed-2 = close;
                open = mkRaw free;
                space = false;
              };
            in
            {
              "(" = [ (bracket "(" ")") ];
              "[" = [ (bracket "[" "]") ];
              "{" = [ (bracket "{" "}") ];
              # Enter between `>` and `</` (ts-autotag's `<div>|</div>`) opens an
              # indented block; the rule never inserts or skips anything.
              ">" = [
                {
                  __unkeyed-1 = ">";
                  __unkeyed-2 = "</";
                  open = false;
                  close = false;
                  open_or_close = false;
                  space = false;
                  backspace = false;
                  languages = [
                    "html"
                    "xml"
                    "tsx"
                    "javascript"
                    "astro"
                  ];
                }
              ];
              # Upstream's generics rule, minus tsx: ts-autotag's `>` closes JSX
              # tags there and would shadow the closer (`Array<T>|>`).
              "<" = [
                {
                  __unkeyed-1 = "<";
                  __unkeyed-2 = ">";
                  open = mkRaw ''function(ctx) return ctx.ts:whitelist("angle").matches and (${free})(ctx) end'';
                  space = false;
                  languages = [
                    "rust"
                    "typescript"
                    "java"
                    "c_sharp"
                    "kotlin"
                    "swift"
                    "dart"
                    "haxe"
                  ];
                }
              ];
            };
        };
        highlights = {
          # A single attribute-less group: no rainbow, unmatched still marked.
          groups = [ "BlinkPairs" ];
          # nvt (cp/timed.lua) is assist-free, so it gets no unmatched hints.
          unmatched_group = mkRaw ''vim.env.NVIM_CP == "timed" and "" or "DiagnosticError"'';
          matchparen.enabled = false;
        };
      };
      lazyLoad.settings.event = [
        "BufReadPost"
        "BufNewFile"
        "InsertEnter"
      ];
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
      lazyLoad.settings.keys =
        map
          (lhs: {
            __unkeyed-1 = lhs;
            mode = "x";
          })
          [
            "<M-h>"
            "<M-j>"
            "<M-k>"
            "<M-l>"
          ];
    };
    plugins.mini-hipatterns = {
      enable = true;
      settings.highlighters.hex_color = mkRaw ''require("mini.hipatterns").gen_highlighter.hex_color()'';
      lazyLoad.settings.event = [
        "BufReadPost"
        "BufNewFile"
      ];
    };
    # Indentation detected from the file (Biome projects indent with tabs).
    # It runs after FileType, so options.nix's 2 spaces and the C family's 4
    # apply only to new or unindented files; an .editorconfig still wins.
    plugins.guess-indent = {
      enable = true;
      lazyLoad.settings.event = [
        "BufReadPre"
        "BufNewFile"
      ];
    };

    plugins.yanky = {
      enable = true;
      settings = {
        highlight = {
          on_yank = false; # the core TextYankPost autocmd already flashes yanks
          timer = 150;
        };
      };
      lazyLoad.settings.keys = [
        (modeKey [ "n" "x" ] "<leader>sy" "function() Snacks.picker.yanky() end" "Yank History")
        {
          __unkeyed-1 = "y";
          __unkeyed-2 = "<Plug>(YankyYank)";
          mode = [
            "n"
            "x"
          ];
          desc = "Yank Text";
        }
        {
          __unkeyed-1 = "p";
          __unkeyed-2 = "<Plug>(YankyPutAfter)";
          mode = [
            "n"
            "x"
          ];
          desc = "Put Text After Cursor";
        }
        {
          __unkeyed-1 = "P";
          __unkeyed-2 = "<Plug>(YankyPutBefore)";
          mode = [
            "n"
            "x"
          ];
          desc = "Put Text Before Cursor";
        }
        {
          __unkeyed-1 = "gp";
          __unkeyed-2 = "<Plug>(YankyGPutAfter)";
          mode = [
            "n"
            "x"
          ];
          desc = "Put Text After Selection";
        }
        {
          __unkeyed-1 = "gP";
          __unkeyed-2 = "<Plug>(YankyGPutBefore)";
          mode = [
            "n"
            "x"
          ];
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

    plugins.inc-rename = {
      enable = true;
      # Loaded on attach: lz.n's stub command for `cmd` has no live preview.
      lazyLoad.settings.event = "LspAttach";
    };

    plugins.dial = {
      enable = true;
      lazyLoad.settings = {
        keys =
          let
            dial =
              mode: dir: g: lhs:
              modeKey mode lhs ''function() require("dial.map").manipulate("${dir}", "${g}${
                if mode == "n" then "normal" else "visual"
              }") end'' "${lib.toSentenceCase dir}";
          in
          [
            (dial "n" "increment" "" "<C-a>")
            (dial "n" "decrement" "" "<C-x>")
            (dial "x" "increment" "" "<C-a>")
            (dial "x" "decrement" "" "<C-x>")
            (dial "n" "increment" "g" "g<C-a>")
            (dial "n" "decrement" "g" "g<C-x>")
            (dial "x" "increment" "g" "g<C-a>")
            (dial "x" "decrement" "g" "g<C-x>")
          ];
        after = mkRaw ''
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
      lazyLoad.settings.keys = [
        (key "<leader>H" ''function() require("harpoon"):list():add() end'' "Harpoon File")
        (key "<leader>h"
          ''function() local h = require("harpoon"); h.ui:toggle_quick_menu(h:list(), { border = vim.o.winborder }) end''
          "Harpoon Quick Menu"
        )
      ]
      ++ map (
        i:
        key "<leader>${toString i}" ''function() require("harpoon"):list():select(${toString i}) end''
          "Harpoon to File ${toString i}"
      ) (lib.range 1 9);
    };

    plugins.treesitter = {
      enable = true;
      highlight.enable = true;
      # Indentation is chosen below, per filetype.
      indent.enable = false;
      folding.enable = true;
      grammarPackages =
        map (name: config.programs.nixvim.plugins.treesitter.package.builtGrammars.${name})
          [
            "astro"
            "bash"
            "c"
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
            "rust"
            "toml"
            "tsx"
            "typescript"
            "vim"
            "vimdoc"
            "xml"
            "yaml"
          ];
    };
    autoGroups.resume_project = { };
    autoCmd = [
      # Plain `nvim` in a project resumes it: the last session, or the file
      # picker for a project not edited before. sesh starts every new project
      # this way (terminal.nix).
      {
        event = "StdinReadPre";
        group = "resume_project";
        callback = mkRaw "function() vim.g.started_with_stdin = true end";
      }
      {
        event = "VimEnter";
        group = "resume_project";
        nested = true;
        callback = mkRaw ''
          function()
            local plain = vim.fn.argc(-1) == 0 and not vim.g.started_with_stdin and #vim.api.nvim_list_uis() > 0
            if not plain or require("core").cp_session() or vim.uv.cwd() == vim.uv.os_homedir() then
              return
            end
            require("lz.n").trigger_load("persistence.nvim")
            require("persistence").load()
            if vim.api.nvim_buf_get_name(0) == "" and vim.bo.buftype == "" and not vim.bo.modified then
              Snacks.picker.files({ cwd = require("core").root() })
            end
          end
        '';
      }
      {
        event = "FileType";
        group = "core";
        # Runtime indent scripts keep working on half-typed code, where
        # tree-sitter's indentexpr misplaces blocks (a statement left
        # unfinished below a new `if {` put it, its body and `}` at column 0).
        # So tree-sitter indents only filetypes without a script (Nix, TOML,
        # ...); TSX/JSX mix both (after/indent, core.jsx_indent).
        desc = "Tree-sitter indentation where no indent script exists";
        callback = mkRaw ''
          function(ev)
            local ft = vim.bo[ev.buf].filetype
            local lang = vim.treesitter.language.get_lang(ft)
            if lang and #vim.treesitter.query.get_files(lang, "indents") > 0
              and #vim.api.nvim_get_runtime_file("indent/" .. ft .. ".*", false) == 0 then
              vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end
          end
        '';
      }
      {
        event = [
          "BufReadPre"
          "BufNewFile"
        ];
        group = "core";
        once = true;
        callback = mkRaw ''
          function()
            require("nvim-treesitter-textobjects").setup({ move = { set_jumps = true } })
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
      lazyLoad.settings.event = [
        "BufReadPost"
        "BufNewFile"
      ];
    };
    plugins.ts-autotag = {
      enable = true;
      # Rust (no rstml grammar here) and plain TypeScript have no tags to
      # close, and the buffer-local `>` would shadow blink.pairs' closer,
      # typing `Vec<u8>` as `Vec<u8>|>`.
      settings.per_filetype = {
        rust.enable_close = false;
        typescript.enable_close = false;
      };
      lazyLoad.settings.event =
        let
          markup = "*.html,*.htm,*.xml,*.svg,*.jsx,*.tsx,*.astro,*.php";
        in
        [
          "BufReadPre ${markup}"
          "BufNewFile ${markup}"
        ];
    };
    plugins.ts-comments = {
      enable = true;
      lazyLoad.settings.event = "DeferredUIEnter";
    };

    plugins.todo-comments = {
      enable = true;
      lazyLoad.settings = {
        event = [
          "BufReadPost"
          "BufNewFile"
        ];
        keys = [
          (key "]t" ''function() require("todo-comments").jump_next() end'' "Next Todo Comment")
          (key "[t" ''function() require("todo-comments").jump_prev() end'' "Prev Todo Comment")
          (key "<leader>st" "function() Snacks.picker.todo_comments() end" "Todo")
          (key "<leader>sT"
            ''function() Snacks.picker.todo_comments({ keywords = { "TODO", "FIX", "FIXME" } }) end''
            "Todo/Fix/Fixme"
          )
        ];
      };
    };

    plugins.grug-far = {
      enable = true;
      settings.headerMaxWidth = 80;
      lazyLoad.settings = {
        cmd = [
          "GrugFar"
          "GrugFarWithin"
        ];
        keys = [
          (modeKey [ "n" "x" ] "<leader>sr" ''
            function()
              local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
              require("grug-far").open({ transient = true, prefills = { filesFilter = ext and ext ~= "" and "*." .. ext or nil } })
            end
          '' "Search and Replace")
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
          (key "<leader>ql" ''function() require("persistence").load({ last = true }) end''
            "Restore Last Session"
          )
          (key "<leader>qd" ''function() require("persistence").stop() end'' "Don't Save Current Session")
        ];
      };
    };

    # C-h/j/k/l cross Neovim splits, then tmux panes (the backend sets the
    # pane's @pane-is-vim, which tmux's root bindings test). Its setup runs
    # tmux synchronously (~15 ms), so it waits for the first frame; a key
    # pressed before that still reaches tmux.
    plugins.smart-splits = {
      enable = true;
      settings = {
        mux.backend = "smart-splits-backend-tmux";
        move.at_edge = "stop";
      };
      lazyLoad.settings = {
        event = "DeferredUIEnter";
        keys = [
          (splitKey "<C-h>" "move_cursor_left" "Go to Left Window")
          (splitKey "<C-j>" "move_cursor_down" "Go to Lower Window")
          (splitKey "<C-k>" "move_cursor_up" "Go to Upper Window")
          (splitKey "<C-l>" "move_cursor_right" "Go to Right Window")
          (splitKey "<A-h>" "resize_left" "Resize Left")
          (splitKey "<A-j>" "resize_down" "Resize Down")
          (splitKey "<A-k>" "resize_up" "Resize Up")
          (splitKey "<A-l>" "resize_right" "Resize Right")
        ];
      };
    };

    plugins.gitsigns = {
      enable = true;
      lazyLoad.settings.event = [
        "BufReadPre"
        "BufNewFile"
      ];
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
        on_attach = mkRaw ''
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
          # A list would merge into the default icons; a function replaces them.
          icons = mkRaw "function() return '' end";
        };
        checkbox.enabled = false;
        # Hovers and other plugin previews: no language row above code blocks
        # (it made hovers a third taller), and no raw text under the cursor.
        overrides.buftype.nofile = {
          anti_conceal.enabled = false;
          code.language = false;
        };
      };
      # Loading runs its plugin/ script, which sets up with the defaults and
      # renders the buffer that triggered the load (often a hover) before this
      # setup; redraw it with the configuration above.
      luaConfig.post = ''require("render-markdown").enable()'';
      lazyLoad.settings.ft = "markdown";
    };

    extraPlugins = [ smart-splits-tmux ];
    # Sourced after the bundled indent scripts for these filetypes.
    extraFiles = {
      "after/indent/typescriptreact.lua".text = ''
        vim.bo.indentexpr = "v:lua.require'core'.jsx_indent('GetTypescriptIndent')"
      '';
      "after/indent/javascriptreact.lua".text = ''
        vim.bo.indentexpr = "v:lua.require'core'.jsx_indent('GetJavascriptIndent')"
      '';
    };

    keymaps = [
      (move "]f" "goto_next_start" "@function.outer" "Next Function Start")
      (move "]c" "goto_next_start" "@class.outer" "Next Class Start")
      (move "]a" "goto_next_start" "@parameter.inner" "Next Parameter Start")
      (move "]F" "goto_next_end" "@function.outer" "Next Function End")
      (move "]C" "goto_next_end" "@class.outer" "Next Class End")
      (move "]A" "goto_next_end" "@parameter.inner" "Next Parameter End")
      (move "[f" "goto_previous_start" "@function.outer" "Prev Function Start")
      (move "[c" "goto_previous_start" "@class.outer" "Prev Class Start")
      (move "[a" "goto_previous_start" "@parameter.inner" "Prev Parameter Start")
      (move "[F" "goto_previous_end" "@function.outer" "Prev Function End")
      (move "[C" "goto_previous_end" "@class.outer" "Prev Class End")
      (move "[A" "goto_previous_end" "@parameter.inner" "Prev Parameter End")
      {
        mode = "n";
        key = "<leader>um";
        action = mkRaw ''function() require("lz.n").trigger_load("render-markdown.nvim"); require("render-markdown").toggle() end'';
        options.desc = "Toggle Markdown Rendering";
      }
    ];
  };
}
