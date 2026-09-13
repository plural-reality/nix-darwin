{ pkgs, settings }:
let
  cli = import ./. { inherit pkgs; };
  hatebu = pkgs.writeShellApplication {
    name = "hatebu";
    text = ''
      export HATENA_USER=${pkgs.lib.escapeShellArg settings.hatenaUser}
      export HATENA_BOOKMARK_RSS_URL='https://b.hatena.ne.jp/%s/bookmark.rss'
      cd ${pkgs.emptyDirectory}
      exec ${cli.hatebucli}/bin/hatebu "$@"
    '';
  };
  gyazo = pkgs.writeShellApplication {
    name = "gyazo";
    text = ''
      GYAZO_ACCESS_TOKEN="$(cat ${pkgs.lib.escapeShellArg settings.gyazoTokenFile})"
      export GYAZO_ACCESS_TOKEN
      export GYAZO_API_ORIGIN=https://api.gyazo.com
      export GYAZO_WEB_ORIGIN=https://gyazo.com
      export GYAZO_UPLOAD_ORIGIN=https://upload.gyazo.com
      export GYAZO_IMAGE_ORIGIN=https://i.gyazo.com
      cd ${pkgs.emptyDirectory}
      exec ${cli.gyazocli}/bin/gyazo "$@"
    '';
  };
  cosensecli = pkgs.writeShellApplication {
    name = "cosensecli";
    text = ''
      COSENSE_PAT="$(cat ${pkgs.lib.escapeShellArg settings.cosenseTokenFile})"
      export COSENSE_PAT
      export COSENSECLI_DEFAULT_PROJECT=${pkgs.lib.escapeShellArg settings.defaultProject}
      unset COSENSECLI_COSENSE_BIN
      cd ${pkgs.emptyDirectory}
      exec ${cli.cosensecli}/bin/cosensecli "$@"
    '';
  };
  packages = { inherit hatebu gyazo cosensecli; };
in
{
  inherit packages;
  servers = pkgs.lib.mapAttrs (name: package: {
    command = "${package}/bin/${name}";
    args = [ "--mcp-server" ];
  }) packages;
}
