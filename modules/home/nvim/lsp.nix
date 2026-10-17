# Language servers through Neovim's native vim.lsp.config/enable, with
# nvim-lspconfig supplying the defaults. Every server binary is a PATH
# fallback: a project's devShell or node_modules copy wins.
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (config.lib.nixvim) mkRaw;

  server =
    settings:
    lib.recursiveUpdate {
      enable = true;
      packageFallback = true;
    } settings;

  # Neovim's runtime and snacks as plain sources: what is on the runtimepath
  # is byte-compiled. A project's own .emmyrc.json or .luarc.json is read last.
  emmyrc = (pkgs.formats.json { }).generate "emmyrc.json" {
    runtime.version = "LuaJIT";
    workspace.library = [
      "${config.programs.nixvim.package}/share/nvim/runtime/lua"
      "${config.programs.nixvim.plugins.snacks.package}/lua"
    ];
  };

  # The mutable checkout, so option completion follows uncommitted edits.
  flake = ''(builtins.getFlake "git+file://${osConfig.programs.nh.flake}")'';
  host = osConfig.networking.hostName;

  jsFiletypes = [
    "javascript"
    "javascriptreact"
    "typescript"
    "typescriptreact"
  ];

  tsInlayHints = {
    enumMemberValues.enabled = true;
    functionLikeReturnTypes.enabled = true;
    parameterNames.enabled = "literals";
    parameterTypes.enabled = true;
    propertyDeclarationTypes.enabled = true;
    variableTypes.enabled = false;
  };

  pick = key: source: desc: {
    inherit key;
    mode = "n";
    action = mkRaw "function() Snacks.picker.${source}() end";
    options.desc = desc;
  };
in
{
  programs.nixvim = {
    plugins.lspconfig.enable = true;

    lsp = {
      inlayHints.enable = true;

      # Explicit modes: nixvim's default "" includes Select mode, where `gr`
      # would swallow text typed into a snippet placeholder.
      keymaps = [
        (pick "gd" "lsp_definitions" "Goto Definition")
        {
          mode = "n";
          key = "gr";
          action = mkRaw "function() Snacks.picker.lsp_references() end";
          options = {
            desc = "References";
            nowait = true;
          };
        }
        (pick "gI" "lsp_implementations" "Goto Implementation")
        (pick "gy" "lsp_type_definitions" "Goto T[y]pe Definition")
        (pick "gai" "lsp_incoming_calls" "C[a]lls Incoming")
        (pick "gao" "lsp_outgoing_calls" "C[a]lls Outgoing")
        (pick "<leader>ss" "lsp_symbols" "LSP Symbols")
        (pick "<leader>sS" "lsp_workspace_symbols" "LSP Workspace Symbols")
        (pick "<leader>cl" "lsp_config" "LSP Info")
        {
          mode = "n";
          key = "<leader>cL";
          action = "<cmd>lsp restart<cr>";
          options.desc = "Restart LSP";
        }
        {
          mode = "n";
          key = "gD";
          lspBufAction = "declaration";
          options.desc = "Goto Declaration";
        }
        {
          mode = "n";
          key = "gK";
          lspBufAction = "signature_help";
          options.desc = "Signature Help";
        }
        {
          mode = [
            "n"
            "x"
          ];
          key = "<leader>ca";
          lspBufAction = "code_action";
          options.desc = "Code Action";
        }
        {
          mode = [
            "n"
            "x"
          ];
          key = "<leader>cc";
          action = mkRaw "vim.lsp.codelens.run";
          options.desc = "Run Codelens";
        }
        {
          mode = "n";
          key = "<leader>cC";
          action = mkRaw "function() vim.lsp.codelens.enable(true, { bufnr = 0 }) end";
          options.desc = "Refresh & Display Codelens";
        }
        {
          mode = "n";
          key = "<leader>cR";
          action = mkRaw "function() Snacks.rename.rename_file() end";
          options.desc = "Rename File";
        }
        {
          mode = "n";
          key = "<leader>cr";
          action = mkRaw ''function() return ":IncRename " .. vim.fn.expand("<cword>") end'';
          options = {
            desc = "Rename";
            expr = true;
          };
        }
        {
          mode = "n";
          key = "<leader>cA";
          action = mkRaw ''function() vim.lsp.buf.code_action({ apply = true, context = { only = { "source" }, diagnostics = {} } }) end'';
          options.desc = "Source Action";
        }
        {
          mode = "n";
          key = "<leader>co";
          action = mkRaw ''function() vim.lsp.buf.code_action({ apply = true, context = { only = { "source.organizeImports" }, diagnostics = {} } }) end'';
          options.desc = "Organize Imports";
        }
        {
          mode = "n";
          key = "]]";
          action = mkRaw "function() Snacks.words.jump(vim.v.count1) end";
          options.desc = "Next Reference";
        }
        {
          mode = "n";
          key = "[[";
          action = mkRaw "function() Snacks.words.jump(-vim.v.count1) end";
          options.desc = "Prev Reference";
        }
      ];

      servers = {
        # Python: basedpyright for types, ruff for lint/format/imports.
        basedpyright = server {
          config = {
            settings.basedpyright = {
              disableOrganizeImports = true;
              analysis = {
                typeCheckingMode = "standard";
                diagnosticMode = "openFilesOnly";
              };
            };
            # Point at the project's .venv (uv or venv) without activating it.
            before_init = mkRaw ''
              function(_, config)
                local python = require("core").venv_python(config.root_dir)
                if python then
                  config.settings = vim.tbl_deep_extend("force", config.settings or {}, { python = { pythonPath = python } })
                end
              end
            '';
          };
        };
        ruff = server {
          # basedpyright owns hover.
          config.on_attach = mkRaw "function(client) client.server_capabilities.hoverProvider = false end";
        };

        clangd = {
          enable = true;
          # Apple's clangd (or a devShell's); see core.clangd.
          package = null;
          config = {
            cmd = mkRaw ''
              function(dispatchers, config)
                return vim.lsp.rpc.start({
                  require("core").clangd(),
                  "--background-index",
                  "--clang-tidy",
                  "--header-insertion=iwyu",
                  "--completion-style=detailed",
                  "--function-arg-placeholders=true",
                  "--fallback-style=llvm",
                  "--all-scopes-completion",
                  "--log=error",
                }, dispatchers, { cwd = config.root_dir })
              end
            '';
            root_markers = [
              ".clangd"
              "compile_commands.json"
              "compile_flags.txt"
              "CMakeLists.txt"
              "Makefile"
              "configure.ac"
              "meson.build"
              "build.ninja"
              ".git"
            ];
            init_options = {
              usePlaceholders = true;
              completeUnimported = true;
              clangdFileStatus = true;
              # Without a compile database (CP files), match the runner's
              # flags: C++20 and the <bits/stdc++.h> shim (cp/sys.lua).
              fallbackFlags = mkRaw ''{ "-std=c++20", "-I" .. vim.g.cp_shim }'';
            };
          };
        };

        # TypeScript 7's native `tsc --lsp` where the project uses it, vtsls
        # (tsserver) otherwise. Exactly one of the two claims a project.
        tsc = {
          enable = true;
          package = null;
          config = {
            filetypes = jsFiletypes;
            root_dir = mkRaw ''
              function(bufnr, on_dir)
                local core = require("core")
                local root = core.js_root(bufnr)
                if root and core.ts_native(root) then on_dir(root) end
              end
            '';
            cmd = mkRaw ''
              function(dispatchers, config)
                local bin = config.root_dir and vim.fs.joinpath(config.root_dir, "node_modules/.bin/tsc")
                if not (bin and vim.fn.executable(bin) == 1) then bin = "${pkgs.typescript_7}/bin/tsc" end
                return vim.lsp.rpc.start({ bin, "--lsp", "--stdio" }, dispatchers, { cwd = config.root_dir })
              end
            '';
            settings."js/ts".inlayHints = tsInlayHints;
          };
        };
        vtsls = server {
          config = {
            filetypes = jsFiletypes;
            root_dir = mkRaw ''
              function(bufnr, on_dir)
                local core = require("core")
                local root = core.js_root(bufnr)
                if root and not core.ts_native(root) then on_dir(root) end
              end
            '';
            on_attach = mkRaw ''
              function(client, bufnr)
                local function action(kind)
                  return function()
                    vim.lsp.buf.code_action({ apply = true, context = { only = { kind }, diagnostics = {} } })
                  end
                end
                local function map(lhs, rhs, desc) vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc }) end
                map("gD", function()
                  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
                  client:exec_cmd({
                    title = "Go to Source Definition",
                    command = "typescript.goToSourceDefinition",
                    arguments = { params.textDocument.uri, params.position },
                  }, { bufnr = bufnr }, function(err, result)
                    if err then return vim.notify(err.message, vim.log.levels.ERROR) end
                    if not result or vim.tbl_isempty(result) then return vim.notify("No source definition found") end
                    vim.lsp.util.show_document(result[1], client.offset_encoding, { focus = true })
                  end)
                end, "Goto Source Definition")
                map("<leader>cM", action("source.addMissingImports.ts"), "Add Missing Imports")
                map("<leader>cu", action("source.removeUnused.ts"), "Remove Unused Imports")
                map("<leader>cD", action("source.fixAll.ts"), "Fix All Diagnostics")
              end
            '';
            settings =
              let
                lang = {
                  updateImportsOnFileMove.enabled = "always";
                  suggest.completeFunctionCalls = true;
                  inlayHints = tsInlayHints;
                };
              in
              {
                vtsls = {
                  enableMoveToFileCodeAction = true;
                  autoUseWorkspaceTsdk = true;
                  experimental = {
                    maxInlayHintLength = 30;
                    completion.enableServerSideFuzzyMatch = true;
                  };
                };
                typescript = lang;
                javascript = lang;
              };
          };
        };

        html = server { };
        cssls = server { };
        tailwindcss = server {
          config.root_dir = mkRaw ''
            function(bufnr, on_dir)
              local root = require("core").tailwind_root(bufnr)
              if root then on_dir(root) end
            end
          '';
        };
        # Both are gated on the project's own config (lspconfig gates Biome).
        biome = server { };
        oxlint = server {
          config.root_dir = mkRaw ''
            function(bufnr, on_dir)
              local root = vim.fs.root(bufnr, require("core").markers.oxlint)
              if root then on_dir(root) end
            end
          '';
        };

        # Schemas load on first attach, not at startup.
        jsonls = server {
          config = {
            settings.json = {
              format.enable = true;
              validate.enable = true;
            };
            before_init = mkRaw ''
              function(_, config)
                config.settings.json.schemas = vim.list_extend(config.settings.json.schemas or {}, require("schemastore").json.schemas())
              end
            '';
          };
        };
        yamlls = server {
          config = {
            settings = {
              redhat.telemetry.enabled = false;
              yaml = {
                keyOrdering = false;
                format.enable = true;
                validate = true;
                schemaStore = {
                  enable = false;
                  url = "";
                };
              };
            };
            before_init = mkRaw ''
              function(_, config)
                config.settings.yaml.schemas = vim.tbl_extend("force", config.settings.yaml.schemas or {}, require("schemastore").yaml.schemas())
              end
            '';
          };
        };

        nixd = server {
          # Its default info level floods lsp.log (server stderr is logged as ERROR).
          config.cmd = [
            "nixd"
            "--log=error"
          ];
          config.settings.nixd = {
            nixpkgs.expr = "${flake}.darwinConfigurations.${host}.pkgs";
            options = {
              darwin.expr = "${flake}.darwinConfigurations.${host}.options";
              home_manager.expr = "${flake}.darwinConfigurations.${host}.options.home-manager.users.type.getSubOptions [ ]";
              nixvim.expr = ''(${flake}.inputs.nixvim.lib.evalNixvim { system = "${pkgs.stdenv.hostPlatform.system}"; }).options'';
            };
          };
        };
        # The Rust language server: about 3x faster than lua_ls here, and its
        # config is static, so no plugin has to feed it Neovim's library.
        emmylua_ls = server {
          config.cmd_env.EMMYLUALS_CONFIG = "${emmyrc}";
        };

        markdown_oxide = server { };
        rumdl = server { };
        tombi = server { };
      };
    };

    # Rust: rustaceanvim owns rust-analyzer, from the toolchain on PATH.
    plugins.rustaceanvim = {
      enable = true;
      # Standalone files share one client through `linkedProjects` instead of
      # joining whichever client started first (mrcjkb/rustaceanvim#190), and
      # std sources outside rustup (fenix) reuse the client that opened them.
      # The second patch drops the notice shown for every standalone file.
      package = pkgs.vimPlugins.rustaceanvim.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./patches/rustaceanvim-standalone.patch
          ./patches/rustaceanvim-quiet-standalone.patch
        ];
      });
      settings = {
        # Standalone (CP) files: the edition the runner compiles with.
        tools.rustc.default_edition = "2024";
        server = {
          # Runs after LspAttach, so <leader>ca and <leader>cd become
          # rust-analyzer's grouped actions and cargo-style diagnostics. nvim-dap
          # must be loaded for rustaceanvim to add debuggables to <leader>dc.
          on_attach = mkRaw ''
            function(_, bufnr)
              require("lz.n").trigger_load("nvim-dap")
              local function map(lhs, args, desc) vim.keymap.set("n", lhs, function() vim.cmd.RustLsp(args) end, { buffer = bufnr, desc = desc }) end
              map("<leader>ca", "codeAction", "Code Action")
              map("<leader>cd", { "renderDiagnostic", "current" }, "Line Diagnostics (rendered)")
              map("<leader>cE", { "explainError", "current" }, "Explain Error")
              map("<leader>cm", "expandMacro", "Expand Macro")
              map("<leader>cK", "openDocs", "Open docs.rs")
            end
          '';
          default_settings.rust-analyzer = {
            cargo = {
              features = "all";
              buildScripts.enable = true;
            };
            check = {
              command = "clippy";
              extraArgs = [ "--no-deps" ];
            };
            procMacro.enable = true;
            files.exclude = [
              ".direnv"
              ".git"
              "target"
              "node_modules"
            ];
            inlayHints = {
              bindingModeHints.enable = false;
              closureReturnTypeHints.enable = "always";
              lifetimeElisionHints = {
                enable = "skip_trivial";
                useParameterNames = true;
              };
              parameterHints.enable = true;
              typeHints.enable = true;
              chainingHints.enable = true;
              closingBraceHints = {
                enable = true;
                minLines = 25;
              };
              reborrowHints.enable = "mutable";
              expressionAdjustmentHints.enable = "never";
            };
          };
        };
        dap.adapter = {
          type = "server";
          port = "\${port}";
          executable = {
            command = "${pkgs.vscode-extensions.vadimcn.vscode-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb";
            args = [
              "--port"
              "\${port}"
            ];
          };
        };
      };
    };
    dependencies.rust-analyzer.enable = false; # the toolchain's (dev.nix)

    plugins.clangd-extensions = {
      enable = true;
      lazyLoad.settings.cmd = [
        "ClangdAST"
        "ClangdTypeHierarchy"
        "ClangdSymbolInfo"
        "ClangdMemoryUsage"
      ];
    };

    # statix, which the flake's checks run and nixd does not report. The
    # autocmd lints on open too (BufEnter: the filetype is set by then).
    plugins.lint = {
      enable = true;
      lintersByFt.nix = [ "statix" ];
      autoCmd = {
        event = [
          "BufEnter"
          "BufWritePost"
          "InsertLeave"
        ];
        pattern = "*.nix";
        group = "core";
      };
      lazyLoad.settings.event = [
        "BufReadPre *.nix"
        "BufNewFile *.nix"
      ];
    };
    extraPackagesAfter = [ pkgs.statix ];

    # MDX is Markdown plus JSX: the markdown parser and servers, and the
    # project's Prettier (which picks its mdx parser from the file name).
    filetype.extension.mdx = "markdown";

    extraPlugins = [ pkgs.vimPlugins.SchemaStore-nvim ];

    autoCmd = [
      {
        event = "FileType";
        group = "core";
        pattern = [
          "c"
          "cpp"
          "objc"
          "objcpp"
          "cuda"
        ];
        desc = "clangd keymaps";
        callback = mkRaw ''
          function(ev)
            local function map(lhs, rhs, desc) vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc }) end
            map("<leader>ch", "<cmd>LspClangdSwitchSourceHeader<cr>", "Switch Source/Header (C/C++)")
            map("<leader>cu", "<cmd>ClangdAST<cr>", "Clangd AST")
            map("<leader>ct", "<cmd>ClangdTypeHierarchy<cr>", "Clangd Type Hierarchy")
          end
        '';
      }
    ];
  };
}
