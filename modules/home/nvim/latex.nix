# LaTeX. VimTeX owns building (continuous latexmk), Skim sync, syntax,
# motions, text objects and the error list. texlab owns completion, hover,
# references, rename and ChkTeX. TeX itself (pdfLaTeX, latexmk, packages)
# comes from the project's devShell when it has one, else from the full TeX
# Live installed below.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.lib.nixvim) mkRaw;
  c = import ../../theme.nix;

  direnv = lib.getExe config.programs.direnv.package;
  # Ghostty's window beside Skim (terminal.nix); wider than this is full screen.
  halfColumns = lib.head (lib.toList config.programs.ghostty.settings.window-width);
  ghosttyApp = "${config.home.homeDirectory}/${config.targets.darwin.copyApps.directory}/Ghostty.app";

  # Skim runs `/bin/sh -c '"<command>" <arguments>'` with launchd's
  # environment (no Nix PATH). A clean nvim with only VimTeX answers in about
  # 50 ms, and no config, hook or missing command can leave it hanging.
  inverseSearch = pkgs.writeShellScript "vimtex-inverse-search" ''
    exec ${lib.getExe' config.programs.nixvim.package "nvim"} --headless --clean \
      --cmd ${lib.escapeShellArg "set rtp^=${config.programs.nixvim.plugins.vimtex.package}"} \
      -c "VimtexInverseSearch $1 $2" -c 'qa!'
  '';

  # Master fixes inverse search when a non-TeX window has focus or a dead
  # nvim is listed first (both in 2.18), and latexmk >= 4.88 warning runs.
  vimtex =
    lib.warnIf (lib.versionAtLeast pkgs.vimPlugins.vimtex.version "2.19")
      "vimtex: nixpkgs has ${pkgs.vimPlugins.vimtex.version}; drop the master pin in nvim/latex.nix"
      (
        pkgs.vimPlugins.vimtex.overrideAttrs {
          version = "2.18-unstable-2026-11-13";
          src = pkgs.fetchFromGitHub {
            owner = "lervag";
            repo = "vimtex";
            rev = "cedc0a172e40d0d1d49670dd0d936d6e2df61de7";
            hash = "sha256-SV9gxWg+6Grkh4fV2qM7l6ovMQY9nNb6/kajCjmRgKw=";
          };
          # Skim opens every PDF, so the post-compile sync must target the
          # compiled document, not whichever one is in front.
          postPatch = ''
            substituteInPlace autoload/vimtex/view/skim.vim \
              --replace-fail "'app.documents[0].go(" "'app.documents.whose({ file: { _equals: theFile }})[0].go("
          '';
        }
      );

  # 5.26.0 republishes diagnostics for every project file on every edit
  # (texlab#1551); the debounce (#1573) is merged but unreleased.
  texlab =
    lib.warnIf (lib.versionAtLeast pkgs.texlab.version "5.27")
      "texlab: nixpkgs has ${pkgs.texlab.version}; drop the master pin in nvim/latex.nix"
      (
        pkgs.texlab.overrideAttrs (_: rec {
          version = "5.26.0-unstable-2026-11-07";
          src = pkgs.fetchFromGitHub {
            owner = "latex-lsp";
            repo = "texlab";
            rev = "e4cae29a052a81820c07b3ab544ee699134bf084";
            hash = "sha256-0iV9yFRVe3obtptVsFTaHRweOgLxNmQG20yxvELhO+c=";
          };
          cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
            inherit src;
            hash = "sha256-S0gzauQXoW1LUGgJuZEl8EYbbUK+5wQ9vgPKIPQAD5E=";
          };
          doCheck = false;
        })
      );

  # ChkTeX alone (0.5 MiB; its deps are already in the system closure). Without
  # a TeX Live tree it would miss its global chktexrc and silently drop checks.
  # A PATH suffix, so a devShell's chktex wins.
  chktex =
    pkgs.runCommand "chktex-${lib.getVersion pkgs.texlive.bin.chktex}"
      {
        nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
      }
      ''
        makeBinaryWrapper ${pkgs.texlive.bin.chktex}/bin/chktex $out/bin/chktex \
          --set-default TEXMFMAIN ${pkgs.texlive.bin.chktex}/share/texmf-dist
      '';

  # One sentence per line. A project badness.toml still takes precedence.
  badnessConfig = pkgs.writeText "badness.toml" ''
    [format]
    wrap = "sentence"
    line-width = 80 # .bib values, display math and arguments; prose ignores it
    indent-width = 2

    [format.no-break-abbreviations]
    default = ["al.", "sec.", "secs.", "eqs.", "tab.", "ref.", "refs.", "ch.", "approx.", "resp.", "vol.", "pp.", "ca.", "jr."]
  '';
in
{
  # TeX for any document without a devShell; a project's direnv still comes
  # first on PATH. The full scheme, so no document fails on a missing package.
  home.packages = [ pkgs.texliveFull ];

  # Defaults for every latexmk run, in the terminal too. A project's
  # .latexmkrc is read after this file and overrides it; VimTeX reads
  # $out_dir from here to find the PDF and the log.
  xdg.configFile."latexmk/latexmkrc".text = ''
    $pdf_mode = 1; # pdfLaTeX, the fastest engine for continuous compiles
    $out_dir = 'build';
    set_tex_cmds('-interaction=nonstopmode -file-line-error -synctex=1 %O %S');
  '';

  programs.nixvim = {
    # Section files hold only prose under a `% !TeX root` line; without this
    # Neovim calls them plaintex.
    globals.tex_flavor = "latex";

    plugins = {
      # Not lazy-loaded: VimTeX is already filetype-lazy (~2 ms at startup),
      # and the viewer's inverse search needs its global command.
      vimtex = {
        enable = true;
        package = vimtex;
        # nixvim's TeX Live would go on the front of nvim's PATH and shadow
        # every devShell's TeX; pstree only serves X11 focus code.
        texlivePackage = null;
        pstreePackage = null;
        settings = {
          # nixvim hard-sets "nvim" (a PATH lookup).
          callback_progpath = lib.mkForce "${config.home.profileDirectory}/bin/nvim";
          view_method = "skim";
          # After every successful compile: revert Skim and show the cursor
          # line, without raising it.
          view_skim_sync = 1;
          view_skim_activate = 0;
          view_skim_reading_bar = 1;
          view_skim_no_select = 1;
          compiler_silent = 1; # the state is in lualine
          compiler_latexmk = {
            # latexmk from the document's direnv, wherever nvim was started.
            executable = [
              direnv
              "exec"
              "."
              "latexmk"
            ];
            options = [
              "-verbose"
              "-file-line-error"
              "-synctex=1"
              "-interaction=nonstopmode"
              # -pvc polls every 2 s by default (938 ms mean save to PDF; 331 ms at 0.2).
              "-e '$sleep_time = 0.2'"
            ];
          };
          quickfix_mode = 2; # open on errors, keep the cursor where it is
          quickfix_open_on_warning = 0;
          complete_enabled = 0; # texlab completes
          syntax_nospell_comments = 1;
          mappings_prefix = "<leader>l";
          mappings_disable = {
            n = [ "K" ]; # texlab hover; package docs on <leader>ld
            i = [ "]]" ]; # delim-close made every ] wait and collapsed ]] into one
            x = [
              "tsd"
              "tsD"
              "tsf"
            ]; # Visual `t` + s… (flash) would hit these
          };
        };
      };

      # No latex grammar is installed; VimTeX's syntax stays in charge if one appears.
      treesitter.highlight.disable = [ "latex" ];

      conform-nvim.settings = {
        formatters_by_ft =
          let
            # Generated tables/numbers and package code keep their layout.
            prose = mkRaw ''
              function(buf)
                local name = vim.api.nvim_buf_get_name(buf)
                if name:find("/gen/", 1, true) or name:match("%.sty$") or name:match("%.cls$") then
                  return { lsp_format = "never" }
                end
                return { "badness" }
              end
            '';
          in
          {
            tex = prose;
            plaintex = prose;
            bib = [ "badness" ];
          };
        formatters.badness = {
          command = "badness";
          # The extension routes .bib to the BibTeX formatter; project config
          # is discovered from cwd.
          args = [
            "format"
            "--stdin-filepath"
            "$FILENAME"
            "-"
          ];
          stdin = true;
          cwd = mkRaw "function(_, ctx) return ctx.dirname end";
          env.BADNESS_CONFIG = "${badnessConfig}";
        };
      };

      # texlab resolves \input/\includegraphics from the project root; the path
      # source would list the buffer's own directory.
      blink-cmp.settings.sources.per_filetype.tex = [
        "lsp"
        "snippets"
        "buffer"
      ];

      which-key.settings.spec = [
        {
          __unkeyed-1 = "<leader>l";
          group = "latex";
          icon = {
            icon = " ";
            color = "green";
          };
        }
      ];

      lualine.settings.sections.lualine_x = lib.mkBefore [
        {
          __unkeyed-1 = mkRaw ''
            function()
              local s = vim.api.nvim_eval("get(get(get(b:, 'vimtex', {}), 'compiler', {}), 'status', -1)")
              return ({ [0] = "󰏤 TeX", "󰑓 TeX", "󰄬 TeX", "󰅖 TeX" })[s] or ""
            end
          '';
          cond = mkRaw ''function() return vim.bo.filetype == "tex" end'';
          color = mkRaw ''
            function()
              local s = vim.api.nvim_eval("get(get(get(b:, 'vimtex', {}), 'compiler', {}), 'status', -1)")
              return { fg = ({ [0] = "${c.grey1}", "${c.yellow}", "${c.green}", "${c.red}" })[s] }
            end
          '';
        }
      ];
    };

    lsp.servers = {
      texlab = {
        enable = true;
        packageFallback = true;
        package = texlab;
        config = {
          # Outside the project's devShell (nvim started elsewhere) texlab
          # still gets its latexmk, kpsewhich and chktex, not the global ones.
          cmd = mkRaw ''
            function(dispatchers, config)
              local root, cmd = config.root_dir, { "texlab" }
              local envrc = root and vim.fs.root(root, ".envrc")
              if envrc and vim.env.DIRENV_DIR ~= "-" .. envrc then
                cmd = { "${direnv}", "exec", root, "texlab" }
              end
              return vim.lsp.rpc.start(cmd, dispatchers, { cwd = root, env = { DIRENV_LOG_FORMAT = "" } })
            end
          '';
          settings.texlab = {
            # VimTeX builds and syncs. These keep the .aux/.log lookups right
            # even when texlab cannot run latexmk to read .latexmkrc.
            build = {
              auxDirectory = "build";
              logDirectory = "build";
              pdfDirectory = "build";
            };
            chktex.onOpenAndSave = true;
            diagnostics.ignoredPatterns = [ "^Unused entry$" ];
            # conform formats; lsp_format = "fallback" must not reach latexindent.
            latexFormatter = "none";
            bibtexFormatter = "none";
            hover.symbols = "glyph";
            inlayHints.labelDefinitions = false;
          };
          # Markdown docs carry base64 PNG glyphs that blink would print raw.
          capabilities.textDocument.completion.completionItem.documentationFormat = [ "plaintext" ];
          # VimTeX's quickfix owns the build log; texlab's copy duplicates it
          # (and misses -file-line-error errors). Its own analysis stays.
          handlers."textDocument/publishDiagnostics" = mkRaw ''
            function(err, params, ctx)
              if params and params.diagnostics then
                params.diagnostics = vim.tbl_filter(function(d) return d.source ~= "latex" end, params.diagnostics)
              end
              return vim.lsp.diagnostic.on_publish_diagnostics(err, params, ctx)
            end
          '';
        };
      };

      # LanguageTool grammar, started for proofreading passes (<leader>lp):
      # ~1 GB RSS and a 4-6 s start.
      ltex_plus = {
        enable = true;
        activate = false;
        packageFallback = true;
        package = pkgs.ltex-ls-plus;
        config = {
          filetypes = [
            "tex"
            "plaintex"
          ];
          settings.ltex = {
            language = "en-US";
            checkFrequency = "save";
            completionEnabled = false;
            disabledRules."en-US" = [ "MORFOLOGIK_RULE_EN_US" ]; # Vim spell owns spelling
          };
          # ltex-ls-plus cannot read word files: pass the Vim spellfile's words.
          before_init = mkRaw ''
            function(_, config)
              local words = {}
              local f = io.open(vim.fn.stdpath("data") .. "/site/spell/en.utf-8.add")
              if f then
                for l in f:lines() do
                  if l ~= "" and not l:find("^#") and not l:find("/") then words[#words + 1] = l end
                end
                f:close()
              end
              config.settings.ltex.dictionary = { ["en-US"] = words }
            end
          '';
        };
      };
    };

    extraPackagesAfter = [
      pkgs.badness
      chktex
    ];

    autoCmd = [
      {
        event = "FileType";
        group = "core";
        pattern = "tex";
        desc = "LaTeX prose";
        callback = mkRaw ''
          function()
            local o = vim.opt_local
            o.wrap = true
            o.breakindent = true
            o.spell = true
            o.spelllang = "en_us"
            o.spellcapcheck = "" -- "the U.S. results"; sentences start on their own line anyway
            o.conceallevel = 0 -- concealed math reflows wrapped lines as the cursor moves
          end
        '';
      }
      {
        event = "User";
        group = "core";
        pattern = "VimtexEventInitPost";
        desc = "Start continuous latexmk (bang: never toggles a running one off)";
        command = "VimtexCompile!";
      }
      {
        event = "User";
        group = "core";
        pattern = "VimtexEventCompileSuccess";
        desc = "Close VimTeX's error list once the errors are fixed";
        callback = mkRaw ''
          function()
            if (vim.fn.getqflist({ title = 1 }).title or ""):find("^VimTeX") then vim.cmd.cclose() end
          end
        '';
      }
      {
        event = "User";
        group = "core";
        pattern = "VimtexEventCompileFailed";
        desc = "A failure without parsed errors focuses VimTeX's output; go back";
        callback = mkRaw ''
          function()
            local out = vim.api.nvim_eval("get(get(get(b:, 'vimtex', {}), 'compiler', {}), 'output', ''')")
            if out ~= "" and vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0)) == vim.uv.fs_realpath(out) then
              vim.cmd.wincmd("p")
            end
          end
        '';
      }
      {
        event = "User";
        group = "core";
        pattern = [
          "VimtexEventCompiling"
          "VimtexEventCompileStarted"
          "VimtexEventCompileSuccess"
          "VimtexEventCompileFailed"
          "VimtexEventCompileStopped"
        ];
        desc = "Refresh the TeX status in lualine";
        callback = mkRaw ''function() if package.loaded.lualine then require("lualine").refresh({ place = { "statusline" } }) end end'';
      }
      {
        event = "User";
        group = "core";
        pattern = "VimtexEventViewReverse";
        desc = "Back to the terminal after Cmd-Shift-click in Skim";
        # By path: `open -b` may pick another copy of the bundle from the
        # store and start a second Ghostty.
        callback = mkRaw ''function() vim.system({ "/usr/bin/open", "-a", "${ghosttyApp}" }) end'';
      }
      {
        event = "User";
        group = "core";
        pattern = [
          "VimtexEventCompileSuccess"
          "VimtexEventView"
        ];
        desc = "Show the PDF: Ghostty leaves full screen for the half beside Skim";
        # The first compile opens Skim, and <leader>lv asks for it; later
        # compiles leave a deliberate full screen alone. Ghostty has no
        # escape sequence for this, so its scripting interface toggles it.
        callback = mkRaw ''
          function(ev)
            if ev.match == "VimtexEventCompileSuccess" then
              if vim.g.tex_pdf_shown then return end
              vim.g.tex_pdf_shown = true
            end
            if not vim.env.GHOSTTY_RESOURCES_DIR then return end
            local width = vim.o.columns
            if vim.env.TMUX then
              width = tonumber(vim.system({ "tmux", "display-message", "-p", "#{client_width}" }, { text = true }):wait().stdout) or width
            end
            if width > ${toString (halfColumns + 8)} then
              vim.system({
                "/usr/bin/osascript",
                "-e",
                'tell application "Ghostty" to perform action "toggle_fullscreen" on focused terminal of selected tab of front window',
              })
            end
          end
        '';
      }
    ];

    extraFiles."after/ftplugin/tex.lua".text = ''
      -- After VimTeX's ftplugin, once per TeX buffer.
      local buf = vim.api.nvim_get_current_buf()
      local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc }) end

      -- No latex parser: mini.ai's tree-sitter f/c/o would error. VimTeX's
      -- ic/ie/id/i$/iP/im take over; mini.ai's b/q/a/... still work.
      vim.b[buf].miniai_config = { custom_textobjects = { f = false, c = false, o = false } }

      -- Neovim's global Visual ]n/[n (node selection) make VimTeX skip its math motions.
      for _, lhs in ipairs({ "]n", "[n", "]N", "[N" }) do
        map("x", lhs, "<Plug>(vimtex-" .. lhs .. ")", "Math Zone")
      end

      map("n", "<leader>ld", "<Plug>(vimtex-doc-package)", "Package Docs")
      map("n", "<leader>lp", function()
        local on = not vim.lsp.is_enabled("ltex_plus")
        vim.lsp.enable("ltex_plus", on)
        vim.notify(on and "LTeX on: checks on save (first run takes a few seconds)" or "LTeX off")
      end, "Proofread (LTeX)")

      -- The LSP keymaps put Snacks.words on ]]/[[ at attach; sections win here.
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("tex_sections_" .. buf, { clear = true }),
        buffer = buf,
        callback = function()
          map("n", "]]", "<Plug>(vimtex-]])", "Next Section")
          map("n", "[[", "<Plug>(vimtex-[[)", "Prev Section")
        end,
      })
    '';
  };

  # Cmd-Shift-click in Skim jumps to the source line in the running nvim.
  targets.darwin.defaults."net.sourceforge.skim-app.skim" = {
    SKTeXEditorPreset = ""; # Custom
    SKTeXEditorCommand = "${inverseSearch}";
    SKTeXEditorArguments = ''%line "%file"'';
  };
}
