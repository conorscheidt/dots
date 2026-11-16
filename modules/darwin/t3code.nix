{
  config,
  lib,
  pkgs,
  ...
}:
let
  profile = "/etc/profiles/per-user/${config.system.primaryUser}/bin";
  # These tools need the desktop app's host. Disable them only in T3's Codex.
  desktopPlugins = [
    "codex-app-tools@openai-bundled"
    "visualize@openai-bundled"
    "browser@openai-bundled"
    "unified-computer-use@openai-bundled"
    "computer-use@openai-bundled"
    "documents@openai-primary-runtime"
    "pdf@openai-primary-runtime"
    "spreadsheets@openai-primary-runtime"
    "presentations@openai-primary-runtime"
    "template-creator@openai-primary-runtime"
  ];
  overrides = [
    "mcp_servers.computer-use.enabled=false"
    "mcp_servers.node_repl.enabled=false"
  ]
  ++ map (plugin: ''plugins."${plugin}".enabled=false'') desktopPlugins;
  policy = (pkgs.formats.json { }).generate "t3code-policy.json" {
    schemaVersion = 1;
    organization = "dots";
    settings.idleCompaction = {
      value = "beforeCacheExpires";
      locked = false;
    };
    limits.providers.instances = {
      codex = {
        locked = false;
        binaryPath = "${profile}/codex";
        launchArgs = lib.escapeShellArgs (
          lib.concatMap (value: [
            "-c"
            value
          ]) overrides
        );
      };
      claudeAgent = {
        locked = false;
        binaryPath = "${profile}/claude";
      };
    };
  };
in
{
  system.build.t3code-policy = policy;
  # T3's documented machine policy leaves login, history and UI state mutable.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    install -d -o root -g wheel -m755 '/Library/Application Support/T3Code'
    install -o root -g wheel -m644 ${policy} '/Library/Application Support/T3Code/policy.json'
  '';
}
