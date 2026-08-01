# The published package contains pre-built ESM. This tiny wrapper project fixes
# the registry artifact and its runtime-only transitive closure in package-lock.
{ pkgs }:

let
  manifest = builtins.fromJSON (builtins.readFile ./package.json);
  version = manifest.dependencies.freee-mcp;
  node = pkgs.nodejs_22;
in
pkgs.buildNpmPackage {
  pname = "freee-mcp";
  inherit version;
  src = ./.;

  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;
  npmDepsHash = "sha256-1q+4rL/mSn7Gzcs41NZauMCRjP536T6/MFZeKDxIdy0=";
  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/lib/freee-mcp"
    cp -R node_modules "$out/lib/freee-mcp/"
    makeWrapper ${node}/bin/node "$out/bin/freee-mcp" \
      --add-flags "$out/lib/freee-mcp/node_modules/freee-mcp/bin/freee-mcp.js"
    runHook postInstall
  '';

  meta = {
    description = "MCP server for the freee APIs";
    homepage = "https://github.com/freee/freee-mcp";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "freee-mcp";
  };
}
