{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.lib.nixvim) mkRaw;
  key = lhs: rhs: desc: {
    mode = "n";
    key = lhs;
    action = mkRaw rhs;
    options.desc = desc;
  };
  modeKey =
    mode: lhs: rhs: desc:
    key lhs rhs desc // { inherit mode; };
  withDap = body: "function() require('lz.n').trigger_load('nvim-dap'); ${body} end";
  withUi =
    body:
    "function() require('lz.n').trigger_load({ 'nvim-dap', 'nvim-dap-view', 'nvim-dap-virtual-text' }); ${body} end";
  dap = fn: withDap "require('dap').${fn}";
  codelldb = "${pkgs.vscode-extensions.vadimcn.vscode-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb";
  jsDebug = lib.getExe' pkgs.vscode-js-debug "js-debug";
  neotest = body: "function() require('lz.n').trigger_load('neotest'); ${body} end";
in
{
  programs.nixvim = {
    plugins.dap = {
      enable = true;
      lazyLoad.settings.lazy = true;
      adapters.servers = {
        codelldb = {
          port = "\${port}";
          executable = {
            command = codelldb;
            args = [
              "--port"
              "\${port}"
            ];
          };
        };
        pwa-node = {
          host = "localhost";
          port = "\${port}";
          executable = {
            command = jsDebug;
            args = [ "\${port}" ];
          };
        };
        pwa-chrome = {
          host = "localhost";
          port = "\${port}";
          executable = {
            command = jsDebug;
            args = [ "\${port}" ];
          };
        };
      };
      configurations =
        let
          native = {
            type = "codelldb";
            request = "launch";
            name = "Launch file";
            program = mkRaw ''function() return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file") end'';
            cwd = "\${workspaceFolder}";
          };
          attachNative = {
            type = "codelldb";
            request = "attach";
            name = "Attach to process";
            pid = mkRaw ''require("dap.utils").pick_process'';
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
              processId = mkRaw ''require("dap.utils").pick_process'';
              cwd = "\${workspaceFolder}";
            }
            {
              type = "pwa-chrome";
              request = "launch";
              name = "Launch Chrome";
              url = mkRaw ''function() return vim.fn.input("URL: ", "http://localhost:5173") end'';
              webRoot = "\${workspaceFolder}";
            }
          ];
        in
        {
          c = [
            native
            attachNative
          ];
          cpp = [
            native
            attachNative
          ];
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
        dapBreakpoint = {
          text = " ";
          texthl = "DiagnosticError";
        };
        dapBreakpointCondition = {
          text = " ";
          texthl = "DiagnosticWarn";
        };
        dapBreakpointRejected = {
          text = " ";
          texthl = "DiagnosticError";
        };
        dapLogPoint = {
          text = ".>";
          texthl = "DiagnosticInfo";
        };
      };
      luaConfig.post = ''
        vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })
        local dap = require("dap")
        local function close() if package.loaded["dap-view"] then require("dap-view").close(true) end end
        dap.listeners.after.event_initialized.dapview = function()
          require("lz.n").trigger_load({ "nvim-dap-view", "nvim-dap-virtual-text" })
          require("dap-view").open()
        end
        dap.listeners.before.event_terminated.dapview = close
        dap.listeners.before.event_exited.dapview = close
      '';
    };

    keymaps = [
      (key "<leader>dB" (withDap "require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: '))")
        "Breakpoint Condition"
      )
      (key "<leader>db" (dap "toggle_breakpoint()") "Toggle Breakpoint")
      # A single C, C++ or Rust file is built and launched; projects and a
      # running session go to nvim-dap's own configurations.
      (key "<leader>dc" (withDap ''
        local dap = require("dap")
        if dap.session() or not require("cp.run").debug() then dap.continue() end
      '') "Debug/Continue")
      (key "<leader>da" (withDap ''
        local args = vim.split(vim.fn.input("Run with args: "), " ", { trimempty = true })
        require("dap").continue({ before = function(config) return vim.tbl_extend("force", config, { args = args }) end })
      '') "Run with Args")
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
      (key "<leader>dw" (withDap "require('dap.ui.widgets').hover()") "Widgets")
      (key "<leader>du" (withUi "require('dap-view').toggle(true)") "Dap View")
      (modeKey [ "n" "x" ] "<leader>de" (withUi "require('dap-view').add_expr()") "Watch Expression")
      (key "<leader>tt" (neotest ''require("neotest").run.run(vim.fn.expand("%"))'') "Run File")
      (key "<leader>tT" (neotest ''require("neotest").run.run(vim.uv.cwd())'') "Run All Test Files")
      (key "<leader>tr" (neotest ''require("neotest").run.run()'') "Run Nearest")
      (key "<leader>tl" (neotest ''require("neotest").run.run_last()'') "Run Last")
      (key "<leader>ts" (neotest ''require("neotest").summary.toggle()'') "Toggle Summary")
      (key "<leader>to" (neotest ''require("neotest").output.open({ enter = true, auto_close = true })'')
        "Show Output"
      )
      (key "<leader>tO" (neotest ''require("neotest").output_panel.toggle()'') "Toggle Output Panel")
      (key "<leader>tS" (neotest ''require("neotest").run.stop()'') "Stop")
      (key "<leader>tw" (neotest ''require("neotest").watch.toggle(vim.fn.expand("%"))'') "Toggle Watch")
      (key "<leader>td"
        (neotest ''require("lz.n").trigger_load("nvim-dap"); require("neotest").run.run({ strategy = "dap" })'')
        "Debug Nearest"
      )
    ];

    # One panel with switchable views instead of dap-ui's window grid.
    plugins.dap-view = {
      enable = true;
      lazyLoad.settings.lazy = true;
    };

    plugins.dap-virtual-text = {
      enable = true;
      lazyLoad.settings.lazy = true;
    };

    plugins.dap-python = {
      enable = true;
      # Nixvim folds this setup into dap's lazy hook; its module must already
      # be on runtimepath when debugging any language, not only Python.
      resolvePython = "function() return require('core').venv_python(vim.api.nvim_buf_get_name(0)) end";
    };

    plugins.neotest = {
      enable = true;
      lazyLoad.settings.lazy = true;
      adapters = {
        vitest.enable = true;
        python = {
          enable = true;
          settings = {
            runner = "pytest";
            python = mkRaw ''function() return require("core").venv_python(vim.fn.getcwd()) or "python3" end'';
            dap.justMyCode = false;
          };
        };
      };
      settings = {
        adapters = [ ''require("rustaceanvim.neotest")'' ];
        status.virtual_text = true;
        output.open_on_run = true;
        quickfix.open = true;
      };
    };
  };
}
