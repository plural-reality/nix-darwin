{ lib }:
{
  templateScope,
  template,
  extensions ? [ ".md" ],
}:
let
  # 1. Filter files in templateScope based on extensions
  files = lib.filterAttrs (
    name: type: type == "regular" && lib.any (ext: lib.hasSuffix ext name) extensions
  ) (builtins.readDir templateScope);

  fileNames = builtins.attrNames files;

  # 2. Generate search/replace pairs
  # Syntax: @[filename] or @[filename.ext]
  # Note: logic assumes the extension to strip is the last one in the list if simplified,
  # but here we map over all extensions to be safe or just support exact match + strict extension removal.
  # For simplicity and robustness matching the previous logic:

  # Generate search patterns for "filename with extension" and "filename without extension"
  # We assume we want to support @[foo.md] and @[foo] for a file "foo.md".

  search = lib.flatten (
    map (
      name:
      let
        # Find which extension this file has
        ext = lib.findFirst (e: lib.hasSuffix e name) "" extensions;
        base = if ext != "" then lib.removeSuffix ext name else name;
      in
      [
        "@[${name}]"
        "@[${base}]"
      ]
    ) fileNames
  );

  replace = lib.flatten (
    map (
      name:
      let
        content = builtins.readFile (templateScope + "/${name}");
      in
      [
        content
        content
      ]
    ) fileNames
  );

  baseTemplate = builtins.readFile template;
in
builtins.replaceStrings search replace baseTemplate
