{
  config,
  lib,
  pkgs,
  ...
}: let
  app = pkgs.callPackage ../../pkgs/zathura {};
  bundle = "${config.home.homeDirectory}/${config.targets.darwin.copyApps.directory}/Zathura.app";
  lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister";
  duti = lib.getExe pkgs.duti;
in {
  home.packages = [app];

  xdg.configFile."zathura/zathurarc".source = ../../pkgs/zathura/zathurarc;

  # Register the copied bundle (never a /nix/store path) and make it the PDF
  # handler; only touches LaunchServices when something is out of date.
  home.activation.zathuraDefaultPdf = lib.hm.dag.entryAfter ["copyApps"] ''
    app=${lib.escapeShellArg bundle}
    if [[ -x "$app/Contents/MacOS/zathura" ]]; then
      run ${lsregister} -f "$app"
      if [[ "$(${duti} -x pdf 2>/dev/null | /usr/bin/sed -n 3p)" != com.pwmt.zathura ]]; then
        run ${duti} -s com.pwmt.zathura com.adobe.pdf all
      fi
    fi
  '';
}
