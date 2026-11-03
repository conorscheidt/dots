{
  lib,
  pkgs,
  ...
}:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    mutableExtensionsDir = true;
    profiles.default = {
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = true;
      extensions =
        (with pkgs.vscode-extensions; [
          asvetliakov.vscode-neovim
          charliermarsh.ruff
          ms-python.debugpy
          ms-python.python
          ms-python.vscode-pylance
          ms-toolsai.jupyter
          ms-toolsai.jupyter-keymap
          ms-toolsai.jupyter-renderers
          sainnhe.gruvbox-material
          tamasfe.even-better-toml
        ])
        # nixpkgs lags this one.
        ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            name = "vscode-python-envs";
            publisher = "ms-python";
            version = "1.42.0";
            arch = "darwin-arm64";
            hash = "sha256-5MU408AWJ5KnjB5dtD2Ce3i+pnGAS1YoWLH6G13bXSA=";
          }
        ];
      userSettings = {
        "extensions.autoUpdate" = false;
        "extensions.ignoreRecommendations" = true;
        "workbench.colorTheme" = "Gruvbox Material Dark";
        "workbench.sideBar.location" = "right";
        "workbench.activityBar.location" = "top";
        "workbench.startupEditor" = "none";
        "workbench.tips.enabled" = false;
        "window.commandCenter" = false;
        "editor.fontFamily" = "'FiraCode Nerd Font Mono', monospace";
        "editor.fontLigatures" = true;
        "editor.minimap.enabled" = false;
        "editor.stickyScroll.enabled" = false;
        "breadcrumbs.enabled" = false;
        "files.autoSave" = "afterDelay";
        "git.autofetch" = true;
        "terminal.integrated.profiles.osx".fish = {
          path = lib.getExe pkgs.fish;
          args = [ "--login" ];
        };
        "terminal.integrated.defaultProfile.osx" = "fish";
        "terminal.integrated.automationProfile.osx".path = "/bin/sh";
        "terminal.integrated.fontLigatures.enabled" = true;
        "terminal.integrated.enableImages" = true;
        "vscode-neovim.neovimClean" = true;
        "vscode-neovim.neovimExecutablePaths.darwin" = lib.getExe pkgs.neovim-unwrapped;
        "extensions.experimental.affinity"."asvetliakov.vscode-neovim" = 1;
        "python.defaultInterpreterPath" = "\${workspaceFolder}/.venv";
        "python.analysis.typeCheckingMode" = "strict";
        "python.analysis.autoImportCompletions" = true;
        "ruff.nativeServer" = "on";
        "ruff.importStrategy" = "fromEnvironment";
        "ruff.configurationPreference" = "filesystemFirst";
        "[python]" = {
          "editor.defaultFormatter" = "charliermarsh.ruff";
          "editor.formatOnSave" = true;
          "editor.codeActionsOnSave" = {
            "source.fixAll.ruff" = "explicit";
            "source.organizeImports.ruff" = "explicit";
          };
        };
        "notebook.formatOnSave.enabled" = true;
        "notebook.codeActionsOnSave" = {
          "notebook.source.fixAll" = "explicit";
          "notebook.source.organizeImports" = "explicit";
        };
        "notebook.lineNumbers" = "on";
        "notebook.output.scrolling" = true;
        "[toml]"."editor.defaultFormatter" = "tamasfe.even-better-toml";
      };
    };
  };
}
