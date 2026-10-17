{
  config,
  lib,
  pkgs,
  ...
}: let
  app = pkgs.callPackage ../../pkgs/zathura {};
  bundle = "${config.home.homeDirectory}/${config.targets.darwin.copyApps.directory}/Zathura.app";
  duti = lib.getExe pkgs.duti;
in {
  home.packages = [app];

  xdg.configFile."zathura/zathurarc".source = ../../pkgs/zathura/zathurarc;

  # The copied bundle (never a /nix/store path) is registered by defaultApps
  # in apps.nix; claim PDFs only when another app currently owns them.
  home.activation.zathuraDefaultPdf = lib.hm.dag.entryAfter ["defaultApps"] ''
    app=${lib.escapeShellArg bundle}
    if [[ -x "$app/Contents/MacOS/zathura" ]]; then
      if [[ "$(${duti} -x pdf 2>/dev/null | /usr/bin/sed -n 3p)" != com.pwmt.zathura ]]; then
        run ${duti} -s com.pwmt.zathura com.adobe.pdf all
      fi
    fi
  '';
}
