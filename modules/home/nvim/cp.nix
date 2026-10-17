# Competitive programming: leetcode.nvim, competitest, the <leader>r* runner,
# leetgen harnesses and the `lc` / `nvt` launchers. The runner works on any
# file and runs every local test; leetcode.nvim (<leader>j) and competitest
# (<leader>rv, which only receives problems from the browser) exist only in
# lc/nvt sessions.
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
}:
let
  inherit (config.lib.nixvim) mkRaw toLuaObject;
  inherit (config.programs.nixvim) plugins;
  nvim = "${config.programs.nixvim.build.package}/bin/nvim";

  # cp/<name>.lua -> lua/cp/<name>.lua (init.lua is `require("cp")`)
  luaModules =
    lib.mapAttrs' (name: _: lib.nameValuePair "lua/cp/${name}" { source = ./cp + "/${name}"; })
      (
        lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".lua" name) (builtins.readDir ./cp)
      );

  fn = body: mkRaw "function() ${body} end";
  cpSession = fn "return (vim.env.NVIM_CP or '') ~= ''";
  map = key: body: desc: {
    mode = "n";
    inherit key;
    action = fn body;
    options.desc = desc;
  };
  run =
    key: opts: desc:
    map "<leader>r${key}" "require('cp.run').run(${opts})" desc;
  # Local LeetCode harnesses act on the CP root, so like the plugins they are
  # CP-session only.
  harness = [
    (map "<leader>jr" "require('cp.leetgen').run_local()" "Run Testcases Locally")
    (map "<leader>jH" "require('cp.leetgen').harness()" "Generate Local Harness and Testcases")
    (map "<leader>ja" "require('cp.cases').add()" "Add Local Testcase")
    (map "<leader>je" "require('cp.cases').edit()" "Edit Local Testcase")
  ]
  ++ lib.optionals plugins.snacks.enable [
    (map "<leader>jf" "Snacks.picker.files({ cwd = require('cp').root(), title = 'Past solutions' })"
      "Find Past Solution"
    )
    (map "<leader>jg" "Snacks.picker.grep({ cwd = require('cp').root(), title = 'Grep solutions' })"
      "Grep Past Solutions"
    )
    (map "<leader>jh" "Snacks.picker.git_log_file()" "Solution History")
  ];
  leet = key: cmd: desc: {
    __unkeyed-1 = "<leader>j${key}";
    __unkeyed-2 = "<cmd>Leet${cmd}<cr>";
    inherit desc;
  };
  competi = key: cmd: desc: {
    __unkeyed-1 = "<leader>r${key}";
    __unkeyed-2 = "<cmd>CompetiTest ${cmd}<cr>";
    inherit desc;
  };
  group = key: name: icon: color: {
    __unkeyed-1 = "<leader>${key}";
    group = name;
    mode = [
      "n"
      "x"
    ];
    icon = { inherit icon color; };
  };
in
{
  programs.nixvim = {
    extraFiles = luaModules;

    globals = {
      # LeetCode rejects stock curl's TLS fingerprint.
      cp_curl = "${pkgs.curl-impersonate}/bin/curl_chrome136";
      # <bits/stdc++.h> for libc++, used when a root has no .include/ of its own.
      cp_shim = "${./cp/include}";
      # Parser, printer and node types for generated Rust harnesses.
      cp_leetgen_rs = "${./cp/leetgen.rs}";
    };

    extraConfigLuaPre = ''
      if (vim.env.NVIM_CP or "") ~= "" then
        vim.g.cp_session = true
        -- The harness keys; nixvim's own keymaps can't be conditional.
        for _, map in ipairs(${toLuaObject harness}) do
          vim.keymap.set(map.mode, map.key, map.action, map.options)
        end
        if vim.env.NVIM_CP == "timed" then
          require("cp.timed").setup()
        end
      end
    '';

    keymaps = [
      (run "r" "{}" "Run (Sanitized, input.txt)")
      (run "n" "{ use_input = false }" "Run (Sanitized, No Stdin)")
      (run "p" "{ sanitize = false }" "Run (Plain, No Sanitizers)")
      (run "c" "{ compile_only = true }" "Compile Only")
      (map "<leader>rt" "require('cp.run').test()" "Run All Testcases")
      (map "<leader>ra" "require('cp.run').pin()" "Add Testcase from input.txt")
      (map "<leader>re" "require('cp.run').edit_cases()" "Edit a Testcase")
      (map "<leader>rf" "require('cp.run').load_failed()" "Failing Testcase to input.txt")
      (map "<leader>ri" "require('cp.run').edit_input()" "Edit input.txt")
      (map "<leader>rk" "require('cp.run').stop()" "Kill Running Process")
      (map "<leader>rP" "require('cp.run').pch_build()" "Rebuild Precompiled Headers")
    ];

    plugins = {
      leetcode = {
        enable = true;
        lazyLoad.settings = {
          enabled = cpSession;
          cmd = "Leet";
          # `lc` starts `nvim leetcode.nvim`: load before VimEnter so the
          # plugin's own startup hook opens the dashboard.
          lazy = mkRaw "vim.fn.argv(0, -1) ~= 'leetcode.nvim'";
          before = fn ''
            require("cp").session()
            vim.g.plenary_curl_bin_path = vim.g.cp_curl
          '';
          keys = [
            (leet "j" "" "Menu (Dashboard)")
            (leet "l" " list" "Problem List")
            (leet "L" " lang" "Change Language (C++ / Rust / …)")
            (leet "R" " run" "Run on LeetCode (Remote)")
            (leet "s" " submit" "Submit")
            (leet "c" " console" "Console (Results)")
            (leet "o" " tabs" "Switch Open Problem")
            (leet "x" " restore" "Repair Broken Layout")
            (leet "d" " desc" "Toggle Description")
            (leet "i" " info" "Problem Info")
            (leet "b" " open" "Open in Browser")
            (leet "X" " reset" "Reset to Empty Snippet")
            (leet "p" " last_submit" "Pull Last Submitted Code")
            (leet "D" " daily" "Daily Question")
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
          lang = mkRaw "vim.env.LEETCODE_LANG or 'cpp'";
          storage = {
            home = mkRaw "require('cp').paths().leetcode";
            # Spelled-out default: ~/.cache/nvim/leetcode keeps the existing login.
            cache = mkRaw "vim.fn.stdpath('cache') .. '/leetcode'";
          };
          injector = {
            cpp = {
              before = [
                "#include <bits/stdc++.h>"
                "using namespace std;"
              ];
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
              before = [
                "#![allow(dead_code, unused)]"
                "struct Solution;"
              ];
              after = [
                ""
                "// `cargo`-free local harness: <leader>rr compiles this file with"
                "// rustc directly. Everything outside the solution markers"
                "// is excluded from remote runs and submissions."
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
          hooks.question_enter = [ (mkRaw "function(q) require('cp').question_enter(q) end") ];
        };
      };

      competitest = {
        enable = true;
        lazyLoad.settings = {
          enabled = cpSession;
          cmd = "CompetiTest";
          before = fn "require('cp').session()";
          keys = [
            (competi "v" "receive problem" "Receive Problem from Browser")
            (competi "V" "receive contest" "Receive Contest from Browser")
          ];
        };
        settings = {
          # Received testcases land where <leader>rt reads them.
          testcases_directory = "./testcases";
          template_file = mkRaw "require('cp').templates()";
          evaluate_template_modifiers = true;
          received_problems_path = mkRaw "require('cp').root() .. '/codeforces/$(JUDGE)/$(CONTEST)/$(PROBLEM).$(FEXT)'";
          received_contests_directory = mkRaw "require('cp').root() .. '/codeforces/$(JUDGE)/$(CONTEST)'";
        };
      };

      which-key.settings.spec = lib.mkIf plugins.which-key.enable [
        (group "r" "run" " " "green")
        (group "j" "leetcode" "󰘧 " "orange")
      ];
    };
  };

  home.packages = [
    (pkgs.writeShellApplication {
      name = "lc";
      text = ''
        # CP mode rooted here: the leetcode.nvim dashboard, or the given files.
        # An explicit startup language; :Leet lang changes the current question.
        if [ "''${1:-}" = "--lang" ]; then
          case "''${2:-}" in
            cpp|rust) export LEETCODE_LANG="$2"; shift 2 ;;
            *) echo "Usage: lc [--lang cpp|rust] [nvim arguments...]" >&2; exit 2 ;;
          esac
        fi
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
