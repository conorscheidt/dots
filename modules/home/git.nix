let
  c = import ../theme.nix;
in {
  programs = {
    git = {
      enable = true;
      lfs.enable = true;
      ignores = [".DS_Store" ".direnv/" ".envrc.local" ".claude/settings.local.json"];
      signing = {
        format = "ssh";
        key = "~/.ssh/id_ed25519_signing";
        signByDefault = true;
      };
      settings = {
        user = {
          name = "Conor Scheidt";
          email = "c@crs.so";
        };
        alias = {
          st = "status --short --branch";
          co = "checkout";
          br = "branch";
          lg = "log --graph --pretty=format:'%C(red)%h%C(reset) -%C(yellow)%d%C(reset) %s %C(green)(%cr) %C(blue)<%an>%C(reset)' --abbrev-commit";
        };
        init.defaultBranch = "main";
        core.editor = "nvim";
        feature.manyFiles = true; # index v4 + untracked cache
        gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
        tag = {
          gpgSign = true;
          sort = "version:refname";
        };
        column.ui = "auto";
        branch.sort = "-committerdate";
        pull.rebase = true;
        push = {
          autoSetupRemote = true;
          followTags = true;
        };
        rebase = {
          autoStash = true;
          updateRefs = true;
        };
        fetch = {
          prune = true;
          pruneTags = true;
          writeCommitGraph = true;
          parallel = 8;
        };
        submodule.recurse = true;
        diff = {
          algorithm = "histogram";
          colorMoved = "default";
        };
        merge.conflictStyle = "zdiff3";
        commit.verbose = true;
        rerere.enabled = true;
        transfer.fsckObjects = true;
      };
    };

    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        line-numbers = true;
        hyperlinks = true;
        syntax-theme = "ansi";
        file-style = "${c.blue} bold";
        file-decoration-style = "${c.bg3} ul";
        hunk-header-style = "omit";
        plus-style = "syntax ${c.bg_diff_green}";
        plus-emph-style = "syntax #4a5a2a";
        minus-style = "syntax ${c.bg_diff_red}";
        minus-emph-style = "syntax #5a2a28";
        line-numbers-zero-style = c.grey0;
        line-numbers-plus-style = c.green;
        line-numbers-minus-style = c.red;
      };
    };

    lazygit = {
      enable = true;
      settings.gui = {
        nerdFontsVersion = "3";
        theme = {
          activeBorderColor = [c.orange "bold"];
          inactiveBorderColor = [c.grey0];
          optionsTextColor = [c.blue];
          selectedLineBgColor = [c.bg1];
          cherryPickedCommitBgColor = [c.bg3];
          cherryPickedCommitFgColor = [c.orange];
          unstagedChangesColor = [c.red];
          defaultFgColor = [c.fg];
          searchingActiveBorderColor = [c.yellow];
        };
      };
    };

    gh = {
      enable = true;
      settings = {
        git_protocol = "https";
        aliases.co = "pr checkout";
      };
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        "github.com".User = "git";
        moore = {
          HostName = "moore.wot.eecs.northwestern.edu";
          User = "dcp2924";
        };
        vps = {
          HostName = "212.56.45.37";
          User = "root";
        };
        "*" = {
          # Apple's ssh knows UseKeychain; Nix-built OpenSSH (used by mosh) does not.
          IgnoreUnknown = "UseKeychain";
          IdentityFile = "~/.ssh/id_ed25519";
          IdentitiesOnly = true;
          AddKeysToAgent = "yes";
          UseKeychain = true;
          ForwardAgent = false;
          HashKnownHosts = true;
          ServerAliveInterval = 30;
          ServerAliveCountMax = 3;
          ControlMaster = "auto";
          ControlPath = "~/.ssh/sockets/%C";
          ControlPersist = "10m";
        };
      };
    };
  };

  home.file.".ssh/sockets/.keep".text = "";
}
