# Applies expand-template to all matching files in a source directory,
# producing a new derivation with expanded contents.
# Non-matching files are copied as-is.
{
  pkgs,
  lib,
}:
{
  # Directory containing @[...] reference targets
  templateScope,
  # Source directory to process
  src,
  # File names to expand (matched exactly)
  targetFiles ? [ "SKILL.md" ],
}:
let
  expandTemplate = import ./expand-template.nix { inherit lib; };

  # Recursively collect all files with relative paths
  collectFiles =
    dirPath: prefix:
    let
      entries = builtins.readDir dirPath;
    in
    builtins.concatMap (
      name:
      let
        fullPath = dirPath + "/${name}";
        relPath = if prefix == "" then name else "${prefix}/${name}";
      in
      if entries.${name} == "directory" then
        collectFiles fullPath relPath
      else if entries.${name} == "regular" then
        [ { inherit relPath fullPath name; } ]
      else
        [ ]
    ) (builtins.attrNames entries);

  allFiles = collectFiles src "";

  # Generate shell commands: expand targets via text files, copy the rest
  copyCommands = map (
    file:
    let
      destDir = "$out/${builtins.dirOf file.relPath}";
    in
    if builtins.elem file.name targetFiles then
      let
        expanded = pkgs.writeText file.relPath (expandTemplate {
          inherit templateScope;
          template = file.fullPath;
        });
      in
      ''
        mkdir -p "${destDir}"
        cp "${expanded}" "$out/${file.relPath}"
      ''
    else
      ''
        mkdir -p "${destDir}"
        cp "${file.fullPath}" "$out/${file.relPath}"
      ''
  ) allFiles;
in
pkgs.runCommand "expanded-${builtins.baseNameOf (builtins.toString src)}" { } (
  builtins.concatStringsSep "\n" ([ "mkdir -p $out" ] ++ copyCommands)
)
