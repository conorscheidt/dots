# DAP adapters and neotest; the debug UI loads on the first session.
{
  config,
  lib,
  pkgs,
  ...
}: let
  lua = config.lib.nixvim.mkRaw;
  key = lhs: rhs: desc: {
    mode = "n";
    key = lhs;
    action = lua rhs;
    options.desc = desc;
  };
  modeKey = mode: lhs: rhs: desc: key lhs rhs desc // {inherit mode;};
  withUi = body: "function() require('lz.n').trigger_load({ 'nvim-dap-ui', 'nvim-dap-virtual-text' }); ${body} end";
  dap = fn: "function() require('dap').${fn} end";

  codelldb = "${pkgs.vscode-extensions.vadimcn.vscode-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb";
  jsDebug = lib.getExe' pkgs.vscode-js-debug "js-debug";

  neotest = body: "function() ${body} end";
in {
  programs.nixvim = {
    plugins.dap = {
      enable = true;
      adapters.servers = {
        codelldb = {
          port = "\${port}";
          executable = {
            command = codelldb;
            args = ["--port" "\${port}"];
          };
        };
        pwa-node = {
          host = "localhost";
          port = "\${port}";
          executable = {
            command = jsDebug;
            args = ["\${port}"];
          };
        };
        pwa-chrome = {
          host = "localhost";
          port = "\${port}";
          executable = {
            command = jsDebug;
            args = ["\${port}"];
          };
        };
      };
      configurations = let
        native = {
          type = "codelldb";
          request = "launch";
          name = "Launch file";
          program = lua ''function() return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file") end'';
          cwd = "\${workspaceFolder}";
        };
        attachNative = {
          type = "codelldb";
          request = "attach";
          name = "Attach to process";
          pid = lua ''require("dap.utils").pick_process'';
          cwd = "\${workspaceFolder}";
        };
        js = [
          {
            type = "pwa-node";
            request = "launch";
            name = "Launch file";
            program = "\${file}";
            cwd = "\${workspaceFolder}";
          }
          {
            type = "pwa-node";
            request = "attach";
            name = "Attach";
            processId = lua ''require("dap.utils").pick_process'';
            cwd = "\${workspaceFolder}";
          }
          {
            type = "pwa-chrome";
            request = "launch";
            name = "Launch Chrome";
            url = lua ''function() return vim.fn.input("URL: ", "http://localhost:5173") end'';
            webRoot = "\${workspaceFolder}";
          }
        ];
      in {
        c = [native attachNative];
        cpp = [native attachNative];
        javascript = js;
        typescript = js;
        javascriptreact = js;
        typescriptreact = js;
      };
      signs = {
        dapStopped = {
          text = "󰁕 ";
          texthl = "DiagnosticWarn";
          linehl = "DapStoppedLine";
          numhl = "DapStoppedLine";
        };
        dapBreakpoint.text = " ";
        dapBreakpointCondition.text = " ";
        dapBreakpointRejected = {
          text = " ";
          texthl = "DiagnosticError";
        };
        dapLogPoint.text = ".>";
      };
      # The UI and virtual text load with the first session and follow it.
      luaConfig.post = ''
        vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })
        local dap = require("dap")
        dap.listeners.after.event_initialized.dapui_config = function()
          require("lz.n").trigger_load({ "nvim-dap-ui", "nvim-dap-virtual-text" })
          require("dapui").open({})
        end
        dap.listeners.before.event_terminated.dapui_config = function() if package.loaded.dapui then require("dapui").close({}) end end
        dap.listeners.before.event_exited.dapui_config = function() if package.loaded.dapui then require("dapui").close({}) end end
      '';
    };

    keymaps = [
      (key "<leader>dB" "function() require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: ')) end" "Breakpoint Condition")
      (key "<leader>db" (dap "toggle_breakpoint()") "Toggle Breakpoint")
      (key "<leader>dc" (dap "continue()") "Run/Continue")
      (key "<leader>da" ''
          function()
            local args = vim.split(vim.fn.input("Run with args: "), " ", { trimempty = true })
            require("dap").continue({ before = function(config) return vim.tbl_extend("force", config, { args = args }) end })
          end
        ''
        "Run with Args")
      (key "<leader>dC" (dap "run_to_cursor()") "Run to Cursor")
      (key "<leader>dg" (dap "goto_()") "Go to Line (No Execute)")
      (key "<leader>di" (dap "step_into()") "Step Into")
      (key "<leader>dj" (dap "down()") "Down")
      (key "<leader>dk" (dap "up()") "Up")
      (key "<leader>dl" (dap "run_last()") "Run Last")
      (key "<leader>do" (dap "step_out()") "Step Out")
      (key "<leader>dO" (dap "step_over()") "Step Over")
      (key "<leader>dP" (dap "pause()") "Pause")
      (key "<leader>dr" (dap "repl.toggle()") "Toggle REPL")
      (key "<leader>ds" (dap "session()") "Session")
      (key "<leader>dt" (dap "terminate()") "Terminate")
      (key "<leader>dw" "function() require('dap.ui.widgets').hover() end" "Widgets")
      (key "<leader>du" (withUi "require('dapui').toggle({})") "Dap UI")
      (modeKey ["n" "x"] "<leader>de" (withUi "require('dapui').eval()") "Eval")

      (key "<leader>tt" (neotest ''require("neotest").run.run(vim.fn.expand("%"))'') "Run File")
      (key "<leader>tT" (neotest ''require("neotest").run.run(vim.uv.cwd())'') "Run All Test Files")
      (key "<leader>tr" (neotest ''require("neotest").run.run()'') "Run Nearest")
      (key "<leader>tl" (neotest ''require("neotest").run.run_last()'') "Run Last")
      (key "<leader>ts" (neotest ''require("neotest").summary.toggle()'') "Toggle Summary")
      (key "<leader>to" (neotest ''require("neotest").output.open({ enter = true, auto_close = true })'') "Show Output")
      (key "<leader>tO" (neotest ''require("neotest").output_panel.toggle()'') "Toggle Output Panel")
      (key "<leader>tS" (neotest ''require("neotest").run.stop()'') "Stop")
      (key "<leader>tw" (neotest ''require("neotest").watch.toggle(vim.fn.expand("%"))'') "Toggle Watch")
      (key "<leader>td" (neotest ''require("neotest").run.run({ strategy = "dap" })'') "Debug Nearest")
    ];

    plugins.dap-ui = {
      enable = true;
      lazyLoad.settings.lazy = true;
    };
    plugins.dap-virtual-text = {
      enable = true;
      lazyLoad.settings.lazy = true;
    };

    # debugpy runs from a nixpkgs Python; the program runs with the project's
    # interpreter.
    plugins.dap-python = {
      enable = true;
      resolvePython = "function() return require('core').venv_python(vim.api.nvim_buf_get_name(0)) end";
    };

    plugins.neotest = {
      enable = true;
      adapters = {
        vitest.enable = true;
        python = {
          enable = true;
          settings = {
            runner = "pytest";
            python = lua ''function() return require("core").venv_python(vim.fn.getcwd()) or "python3" end'';
            dap.justMyCode = false;
          };
        };
      };
      settings = {
        # Rust tests go through rust-analyzer (same runnables as :RustLsp).
        adapters = [''require("rustaceanvim.neotest")''];
        status.virtual_text = true;
        output.open_on_run = true;
        quickfix.open = lua ''function() vim.cmd("Trouble qflist open") end'';
      };
      lazyLoad.settings.event = "DeferredUIEnter";
    };
  };
}
