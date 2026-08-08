{ pkgs }:
pkgs.buildNpmPackage {
  pname = "plaud-cli";
  version = "0.3.6";
  src = ./.;
  npmDepsHash = "sha256-tZFQdQfMpe+dxS8fjolLcZ9d8XHQiBGS8V0KTFD3XXc=";
  dontNpmBuild = true;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/plaud-cli" "$out/bin"
    cp -R node_modules "$out/lib/plaud-cli/"
    makeWrapper ${pkgs.nodejs_22}/bin/node "$out/bin/plaud" \
      --add-flags "$out/lib/plaud-cli/node_modules/@plaud-ai/cli/dist/index.js"
    runHook postInstall
  '';
}
