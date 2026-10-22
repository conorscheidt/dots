# Competitive programming: leetcode.nvim, competitest, the <leader>r* runner,
# leetgen harnesses and the `lc` / `nvt` launchers.
#
# AI-free by contract: NVIM_CP (set by the launchers) or vim.g.cp_session (set
# whenever leetcode.nvim or competitest loads) makes the AI loader refuse.
# The CP root is $CP_ROOT / vim.g.cp_root, else the nearest directory with the
# CP layout (.leetgen, .include), else the git root of cwd. Under it:
# leetcode/, templates/, .include/ and .leetgen/ (see cp/init.lua).
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.lib.nixvim) mkRaw;
  inherit (config.programs.nixvim) plugins;
  nvim = "${config.programs.nixvim.build.package}/bin/nvim";

  # cp/<name>.lua -> lua/cp/<name>.lua (init.lua is `require("cp")`)
  luaModules =
    lib.mapAttrs' (name: _: lib.nameValuePair "lua/cp/${name}" {source = ./cp + "/${name}";})
    (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".lua" name) (builtins.readDir ./cp));

  fn = body: mkRaw "function() ${body} end";
  map = key: body: desc: {
    mode = "n";
    inherit key;
    action = fn body;
    options.desc = desc;
  };
  run = key: opts: desc: map "<leader>r${key}" "require('cp.run').run(${opts})" desc;
  leet = key: cmd: desc: {
    __unkeyed-1 = "<leader>j${key}";
    __unkeyed-2 = "<cmd>Leet${cmd}<cr>";
    inherit desc;
  };
  competi = key: cmd: desc: {
    __unkeyed-1 = "<leader>k${key}";
    __unkeyed-2 = "<cmd>CompetiTest ${cmd}<cr>";
    inherit desc;
  };
  group = key: name: icon: color: {
    __unkeyed-1 = "<leader>${key}";
    group = name;
    mode = ["n" "x"];
    icon = {inherit icon color;};
  };
in {
  programs.nixvim = {
    extraFiles = luaModules;

    globals = {
      # LeetCode rejects stock curl's TLS fingerprint.
      cp_curl = "${pkgs.curl-impersonate}/bin/curl_chrome136";
      # <bits/stdc++.h> for libc++, used when a root has no .include/ of its own.
      cp_shim = "${./cp/include}";
    };

    extraConfigLuaPre = ''
      if (vim.env.NVIM_CP or "") ~= "" then
        vim.g.cp_session = true
        if vim.env.NVIM_CP == "timed" then
          require("cp.timed").setup()
        end
      end
    '';

    autoGroups.cp_competitest_wrap = {};
    autoCmd = [
      {
        # CompetiTest panes hold long paths and outputs: wrap mid-token.
        event = "BufWinEnter";
        group = "cp_competitest_wrap";
        callback = mkRaw ''
          function(args)
            if not vim.api.nvim_buf_get_name(args.buf):match("CompetiTest%a+%d*$") then
              return
            end
            for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
              vim.wo[win].wrap = true
              vim.wo[win].linebreak = false
              vim.wo[win].breakindent = true
            end
          end
        '';
      }
    ];

    keymaps =
      [
        (run "r" "{}" "Run (sanitized, + input.txt)")
        (run "n" "{ use_input = false }" "Run (sanitized, no stdin)")
        (run "p" "{ sanitize = false }" "Run (plain, no sanitizers)")
        (run "c" "{ compile_only = true }" "Compile only")
        (map "<leader>ri" "require('cp.run').edit_input()" "Edit input.txt")
        (map "<leader>rk" "require('cp.run').stop()" "Kill running process")
        (map "<leader>rP" "require('cp.run').pch_build()" "Rebuild precompiled headers")
        (map "<leader>jr" "require('cp.leetgen').run_local()" "Run testcases LOCALLY")
        (map "<leader>jH" "require('cp.leetgen').harness()" "Generate local harness + testcases")
        (map "<leader>ja" "require('cp.cases').add()" "Add local testcase")
        (map "<leader>je" "require('cp.cases').edit()" "Edit local testcase")
      ]
      ++ lib.optionals plugins.snacks.enable [
        (map "<leader>jf" "Snacks.picker.files({ cwd = require('cp').root(), title = 'Past solutions' })" "Find past solution")
        (map "<leader>jg" "Snacks.picker.grep({ cwd = require('cp').root(), title = 'Grep solutions' })" "Grep past solutions")
        (map "<leader>jh" "Snacks.picker.git_log_file()" "History of this solution")
      ];

    plugins = {
      leetcode = {
        enable = true;
        lazyLoad.settings = {
          cmd = "Leet";
          # `lc` starts `nvim leetcode.nvim`: load before VimEnter so the
          # plugin's own startup hook opens the dashboard.
          lazy = mkRaw "vim.fn.argv(0, -1) ~= 'leetcode.nvim'";
          before = fn ''
            require("cp").session()
            vim.g.plenary_curl_bin_path = vim.g.cp_curl
          '';
          keys = [
            (leet "j" "" "Menu (dashboard)")
            (leet "l" " list" "Problem list")
            (leet "R" " run" "Run on LeetCode (remote)")
            (leet "s" " submit" "Submit")
            (leet "c" " console" "Console (results)")
            (leet "o" " tabs" "Switch open problem")
            (leet "x" " restore" "Repair broken layout")
            (leet "d" " desc" "Toggle description")
            (leet "i" " info" "Problem info")
            (leet "b" " open" "Open in browser")
            (leet "X" " reset" "Reset to empty snippet")
            (leet "p" " last_submit" "Pull last submitted code")
            (leet "D" " daily" "Daily question")
          ];
        };
        luaConfig.post = ''
          require("cp.buffers").install()
          if not vim.treesitter.language.add("html") then
            vim.notify("leetcode.nvim: no treesitter html parser; descriptions will not render", vim.log.levels.WARN)
          end
        '';
        # Options left out are leetcode.nvim's defaults.
        settings = {
          lang = "cpp";
          picker.provider = lib.mkIf plugins.snacks.enable "snacks-picker";
          storage = {
            home = mkRaw "require('cp').paths().leetcode";
            # Spelled-out default: ~/.cache/nvim/leetcode keeps the existing login.
            cache = mkRaw "vim.fn.stdpath('cache') .. '/leetcode'";
          };
          injector = {
            cpp = {
              before = ["#include <bits/stdc++.h>" "using namespace std;"];
              after = [
                ""
                "#ifdef LOCAL"
                "int main() {"
                "    ios::sync_with_stdio(false);"
                "    cin.tie(nullptr);"
                "    Solution s;"
                "    // construct inputs, call the method, print the result:"
                "    // cout << s.methodName(args) << '\\n';"
                "    return 0;"
                "}"
                "#endif"
              ];
            };
            rust = {
              before = ["#![allow(dead_code, unused)]"];
              after = [
                ""
                "// `cargo`-free local harness: <leader>rr compiles this file with"
                "// rustc directly, and main() is ignored by LeetCode's judge."
                "fn main() {"
                "    // let out = Solution::method_name(args);"
                "    // println!(\"{:?}\", out);"
                "}"
              ];
            };
          };
          console = {
            size.height = "80%";
            result.size = "65%";
            testcase.size = "35%";
          };
          hooks.question_enter = [(mkRaw "function(q) require('cp').question_enter(q) end")];
        };
      };

      competitest = {
        enable = true;
        lazyLoad.settings = {
          cmd = "CompetiTest";
          before = fn "require('cp').session()";
          keys = [
            (competi "a" "add_testcase" "Add testcase")
            (competi "e" "edit_testcase" "Edit testcase")
            (competi "d" "delete_testcase" "Delete testcase")
            (competi "r" "run" "Run all testcases")
            (competi "n" "run_no_compile" "Run (no compile)")
            (competi "u" "show_ui" "Show last results")
            (competi "v" "receive problem" "Receive problem")
            (competi "c" "receive contest" "Receive contest")
          ];
        };
        settings = {
          compile_command = {
            # Same flags as <leader>rr (ASan/UBSan, hardening, PCH when built).
            cpp = {
              exec = "clang++";
              args = mkRaw "require('cp').competitest_cpp()";
            };
            rust = {
              exec = "rustc";
              args = ["--edition" "2021" "-g" "--crate-name" "solution" "-C" "debug-assertions=on" "-C" "overflow-checks=on" "$(FNAME)" "-o" "$(FNOEXT)"];
            };
          };
          testcases_directory = "./testcases";
          output_compare_method = mkRaw "require('cp.compare')";
          view_output_diff = true;
          popup_ui = {
            total_width = 0.9;
            total_height = 0.85;
            layout = [
              [2 "tc"]
              [4 [[2 "si"] [1 "se"]]]
              [5 [[1 "so"] [1 "eo"]]]
            ];
          };
          template_file = mkRaw "require('cp').templates()";
          evaluate_template_modifiers = true;
          received_problems_path = mkRaw "require('cp').root() .. '/codeforces/$(JUDGE)/$(CONTEST)/$(PROBLEM).$(FEXT)'";
          received_contests_directory = mkRaw "require('cp').root() .. '/codeforces/$(JUDGE)/$(CONTEST)'";
        };
      };

      which-key.settings.spec = lib.mkIf plugins.which-key.enable [
        (group "r" "run" " " "green")
        (group "j" "leetcode" "󰘧 " "orange")
        (group "k" "codeforces" "󰙨 " "cyan")
      ];
    };
  };

  home.packages = [
    (pkgs.writeShellApplication {
      name = "lc";
      text = ''
        # CP mode rooted here: the leetcode.nvim dashboard, or the given files.
        export NVIM_CP=1 CP_ROOT="''${CP_ROOT:-$PWD}"
        if [ "$#" -eq 0 ]; then set -- leetcode.nvim; fi
        exec ${nvim} "$@"
      '';
    })
    (pkgs.writeShellApplication {
      name = "nvt";
      text = ''
        # Timed, assist-free mode: no LSP, completion, diagnostics or AI.
        export NVIM_CP=timed
        exec ${nvim} "$@"
      '';
    })
  ];
}
