{ pkgs }:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "codelayer";
  version = "0.20.0";

  src = pkgs.fetchurl {
    url = "https://github.com/humanlayer/humanlayer/releases/download/v${version}/CodeLayer-Stable-darwin-arm64.dmg";
    hash = "sha256-Tgvd1lOGHiymDWdGSVbV0wWhcPTxVFmmTG+XIqHzduM=";
  };

  sourceRoot = "CodeLayer.app";

  nativeBuildInputs = [ pkgs.undmg ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications/CodeLayer.app"
    cp -R . "$out/Applications/CodeLayer.app"

    # Symlink CLI binaries
    mkdir -p "$out/bin"
    ln -s "$out/Applications/CodeLayer.app/Contents/Resources/bin/humanlayer" "$out/bin/humanlayer"
    ln -s "$out/Applications/CodeLayer.app/Contents/Resources/bin/humanlayer" "$out/bin/codelayer"
    ln -s "$out/Applications/CodeLayer.app/Contents/Resources/bin/hld" "$out/bin/hld"
    ln -s "$out/Applications/CodeLayer.app/Contents/Resources/bin/cld" "$out/bin/cld"

    runHook postInstall
  '';

  meta = {
    description = "AI coding agent powered by Claude";
    homepage = "https://humanlayer.dev/";
    platforms = [ "aarch64-darwin" ];
    mainProgram = "humanlayer";
  };
}
