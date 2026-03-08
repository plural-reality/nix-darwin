# XcodeBuildMCP: Nix-packaged MCP server for Xcode integration.
# Eliminates npx runtime downloads — fully hermetic.
#
# The npm tarball ships pre-built JS (build/) and native binaries (bundled/).
# We only need to install npm dependencies and wire up the bin entry.
{ pkgs }:

pkgs.buildNpmPackage rec {
  pname = "xcodebuildmcp";
  version = "2.2.1";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-8jqjxNf8BzBuiXjJSLA5HW+KwexP57CTgqZM3pOQDbw=";
  };

  sourceRoot = "package";

  # Generated from `npm install --package-lock-only` on the extracted tarball.
  # Also strip the prepare script that tries to install git hooks.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    ${pkgs.jq}/bin/jq 'del(.scripts.prepare)' package.json > package.json.tmp \
      && mv package.json.tmp package.json
  '';

  # Pre-built JS — no build step needed
  dontNpmBuild = true;

  npmFlags = [ "--ignore-scripts" ];

  npmDepsHash = "sha256-Djkd/1u0Uk5I4JKUUx9v7K2zrBmFXRoeehHaaYVwDT4=";

  meta = {
    description = "MCP server for Xcode build, test, and simulator operations";
    homepage = "https://github.com/cameroncooke/XcodeBuildMCP";
    license = pkgs.lib.licenses.mit;
    mainProgram = "xcodebuildmcp";
  };
}
