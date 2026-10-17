# Language servers through Neovim's native vim.lsp.config/enable, with
# nvim-lspconfig supplying the defaults. Every server binary is a PATH
# fallback: a project's devShell or node_modules copy wins.
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}: let
  lua = config.lib.nixvim.mkRaw;

  server = settings:
    lib.recursiveUpdate {
      enable = true;
      packageFallback = true;
    }
    settings;

  # The mutable checkout, so option completion follows uncommitted edits.
  flake = ''(builtins.getFlake "${toString config.programs.nh.flake}")'';
  host = osConfig.networking.hostName;

  jsFiletypes = ["javascript" "javascriptreact" "typescript" "typescriptreact"];

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
    action = lua "function() Snacks.picker.${source}() end";
    options.desc = desc;
  };
in {
  programs.nixvim = {
    plugins.lspconfig.enable = true;

    lsp = {
      inlayHints.enable = true;

      keymaps = [
        (pick "gd" "lsp_definitions" "Goto Definition")
        {
          key = "gr";
          action = lua "function() Snacks.picker.lsp_references() end";
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
        (pick "<leader>cl" "lsp_config" "Lsp Info")
        {
          key = "gD";
          lspBufAction = "declaration";
          options.desc = "Goto Declaration";
        }
        {
          key = "gK";
          lspBufAction = "signature_help";
          options.desc = "Signature Help";
        }
        {
          mode = "i";
          key = "<c-k>";
          lspBufAction = "signature_help";
          options.desc = "Signature Help";
        }
        {
          mode = ["n" "x"];
          key = "<leader>ca";
          lspBufAction = "code_action";
          options.desc = "Code Action";
        }
        {
          mode = ["n" "x"];
          key = "<leader>cc";
          action = lua "vim.lsp.codelens.run";
          options.desc = "Run Codelens";
        }
        {
          key = "<leader>cC";
          action = lua "function() vim.lsp.codelens.enable(true, { bufnr = 0 }) end";
          options.desc = "Refresh & Display Codelens";
        }
        {
          key = "<leader>cR";
          action = lua "function() Snacks.rename.rename_file() end";
          options.desc = "Rename File";
        }
        {
          key = "<leader>cr";
          action = lua ''function() return ":IncRename " .. vim.fn.expand("<cword>") end'';
          options = {
            desc = "Rename";
            expr = true;
          };
        }
        {
          key = "<leader>cA";
          action = lua ''function() vim.lsp.buf.code_action({ apply = true, context = { only = { "source" }, diagnostics = {} } }) end'';
          options.desc = "Source Action";
        }
        {
          key = "<leader>co";
          action = lua ''function() vim.lsp.buf.code_action({ apply = true, context = { only = { "source.organizeImports" }, diagnostics = {} } }) end'';
          options.desc = "Organize Imports";
        }
        {
          key = "]]";
          action = lua "function() Snacks.words.jump(vim.v.count1) end";
          options.desc = "Next Reference";
        }
        {
          key = "[[";
          action = lua "function() Snacks.words.jump(-vim.v.count1) end";
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
            before_init = lua ''
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
          config.on_attach = lua "function(client) client.server_capabilities.hoverProvider = false end";
        };

        clangd = {
          enable = true;
          # Apple's clangd (or a devShell's); see core.clangd.
          package = null;
          config = {
            cmd = lua ''
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
            root_dir = lua ''
              function(bufnr, on_dir)
                local core = require("core")
                local root = core.js_root(bufnr)
                if root and core.ts_native(root) then on_dir(root) end
              end
            '';
            cmd = lua ''
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
            filetypes = jsFiletypes ++ ["vue"];
            root_dir = lua ''
              function(bufnr, on_dir)
                local core = require("core")
                local root = core.js_root(bufnr)
                if root and not core.ts_native(root) then on_dir(root) end
              end
            '';
            settings = let
              lang = {
                updateImportsOnFileMove.enabled = "always";
                suggest.completeFunctionCalls = true;
                inlayHints = {
                  enumMemberValues.enabled = true;
                  functionLikeReturnTypes.enabled = true;
                  parameterNames.enabled = "literals";
                  parameterTypes.enabled = true;
                  propertyDeclarationTypes.enabled = true;
                  variableTypes.enabled = false;
                };
              };
            in {
              complete_function_calls = true;
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

        astro = server {};
        svelte = server {};
        html = server {};
        cssls = server {};
        tailwindcss = server {
          config.root_dir = lua ''
            function(bufnr, on_dir)
              local root = require("core").tailwind_root(bufnr)
              if root then on_dir(root) end
            end
          '';
        };
        # Both are gated on the project's own config (lspconfig gates Biome).
        biome = server {};
        oxlint = server {
          config.root_dir = lua ''
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
            before_init = lua ''
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
            before_init = lua ''
              function(_, config)
                config.settings.yaml.schemas = vim.tbl_extend("force", config.settings.yaml.schemas or {}, require("schemastore").yaml.schemas())
              end
            '';
          };
        };

        nixd = server {
          config.settings.nixd = {
            nixpkgs.expr = "import ${flake}.inputs.nixpkgs { }";
            formatting.command = ["alejandra"];
            options = {
              nix-darwin.expr = "${flake}.darwinConfigurations.${host}.options";
              home-manager.expr = "${flake}.darwinConfigurations.${host}.options.home-manager.users.type.getSubOptions [ ]";
            };
          };
        };

        lua_ls = server {
          config.settings.Lua = {
            workspace.checkThirdParty = false;
            codeLens.enable = true;
            completion.callSnippet = "Replace";
            doc.privateName = ["^_"];
            hint = {
              enable = true;
              setType = false;
              paramType = true;
              paramName = "Disable";
              semicolon = "Disable";
              arrayIndex = "Disable";
            };
          };
        };

        marksman = server {};
        taplo = server {};
        bashls = server {};
      };
    };

    # The runtime and plugins on the runtimepath are byte-compiled, which
    # lua_ls cannot read, so point lazydev at their sources.
    plugins.lazydev = {
      enable = true;
      settings = {
        runtime = "${config.programs.nixvim.package}/share/nvim/runtime";
        library = [
          {
            path = "\${3rd}/luv/library";
            words = ["vim%.uv"];
          }
          {
            path = "${config.programs.nixvim.plugins.snacks.package}";
            words = ["Snacks"];
          }
        ];
      };
      lazyLoad.settings.ft = "lua";
    };

    # Rust: rustaceanvim owns rust-analyzer (from the toolchain on PATH; the
    # nixpkgs copy is only a fallback).
    plugins.rustaceanvim = {
      enable = true;
      settings = {
        tools.float_win_config.border = "rounded";
        server = {
          on_attach = lua ''
            function(_, bufnr)
              vim.keymap.set("n", "<leader>cR", function() vim.cmd.RustLsp("codeAction") end, { desc = "Code Action", buffer = bufnr })
              vim.keymap.set("n", "<leader>dr", function() vim.cmd.RustLsp("debuggables") end, { desc = "Rust Debuggables", buffer = bufnr })
            end
          '';
          default_settings.rust-analyzer = {
            cargo = {
              allFeatures = true;
              loadOutDirsFromCheck = true;
              buildScripts.enable = true;
            };
            check = {
              command = "clippy";
              extraArgs = ["--no-deps"];
            };
            procMacro.enable = true;
            files.exclude = [".direnv" ".git" "target" "node_modules"];
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
            args = ["--port" "\${port}"];
          };
        };
      };
    };
    dependencies.rust-analyzer.packageFallback = true;

    plugins.crates = {
      enable = true;
      settings = {
        completion.crates.enabled = true;
        lsp = {
          enabled = true;
          actions = true;
          completion = true;
          hover = true;
        };
      };
      lazyLoad.settings.event = "BufRead Cargo.toml";
    };

    plugins.clangd-extensions = {
      enable = true;
      lazyLoad.settings.ft = ["c" "cpp" "objc" "objcpp" "cuda"];
    };

    # Notebooks open as py:percent through the jupytext CLI and save back to
    # .ipynb (outputs are kept via --update).
    plugins.jupytext = {
      enable = true;
      settings = {
        style = "percent";
        output_extension = "auto";
        force_ft = null;
      };
      # lz.n replays the read through the plugin's own BufReadCmd.
      lazyLoad.settings.event = "BufReadCmd *.ipynb";
    };

    # MDX is Markdown plus JSX: the markdown parser, marksman and the
    # project's Prettier (which picks its mdx parser from the file name).
    filetype.extension.mdx = "markdown";

    extraPlugins = [pkgs.vimPlugins.SchemaStore-nvim];

    autoCmd = [
      {
        event = "FileType";
        group = "core";
        pattern = ["c" "cpp" "objc" "objcpp" "cuda"];
        desc = "clangd keymaps";
        callback = lua ''
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
