{ pkgs }:
let
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  mkCli =
    name: spec:
    (pkgs.buildNpmPackage.override { nodejs = pkgs.nodejs_24; }) {
      pname = name;
      inherit (spec) version npmDepsHash;
      src = pkgs.fetchFromGitHub {
        owner = "yuiseki";
        repo = name;
        inherit (spec) rev hash;
      };
      npmFlags = [ "--ignore-scripts" ];
      npmBuildScript = "build";
      preBuild = pkgs.lib.optionalString (name == "cosensecli") ''
        ${pkgs.python3}/bin/python3 ${./restrict-cosense.py}
      '';

      doInstallCheck = true;
      installCheckPhase = ''
        runHook preInstallCheck
        ${pkgs.python3}/bin/python3 ${./smoke.py} ${name}="$out/bin/${
          if name == "hatebucli" then
            "hatebu"
          else if name == "gyazocli" then
            "gyazo"
          else
            "cosensecli"
        }"
        ${pkgs.lib.optionalString (name == "cosensecli") ''
          export COSENSE_REQUEST_MODULE="$out/lib/node_modules/@yuiseki/cosensecli/node_modules/@helpfeel/cosense-cli/src/lib/request.ts"
          ${pkgs.nodejs_24}/bin/node --import "$out/lib/node_modules/@yuiseki/cosensecli/node_modules/tsx/dist/loader.mjs" --test ${./security.test.mjs}
        ''}
        runHook postInstallCheck
      '';
      meta = {
        description = "Pinned personal record search CLI and read-only MCP server";
        homepage = "https://github.com/yuiseki/${name}";
        platforms = [ "aarch64-darwin" ];
      };
    };
in
builtins.mapAttrs mkCli sources
