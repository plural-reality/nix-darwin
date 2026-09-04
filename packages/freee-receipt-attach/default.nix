# One typed financial mutation capability. It calls the pinned official local
# freee-mcp over stdio; OAuth files remain in ~/.config/freee-mcp and never enter
# the store, argv, or stdout.
{ pkgs, freeeMcp }:
pkgs.writeShellApplication {
  name = "freee-receipt-attach";
  runtimeInputs = [
    freeeMcp
    pkgs.nodejs_22
  ];
  text = ''
    export FREEE_MCP_BIN=${freeeMcp}/bin/freee-mcp
    exec ${pkgs.nodejs_22}/bin/node --experimental-strip-types ${../../scripts/freee-receipt-attach.ts} "$@"
  '';
}
