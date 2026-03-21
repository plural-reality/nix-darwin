# Packages Claude Code skills as ZIP files uploadable to Claude Desktop.
#
# Claude Desktop requires:
#   my-skill.zip/my-skill/Skill.md   (YAML frontmatter: name + description)
#
# Our source uses SKILL.md (all caps); some files lack frontmatter.
# This derivation normalises both.
{ pkgs, skillsDir }:
let
  lib = pkgs.lib;

  entries = builtins.readDir skillsDir;
  skillNames = builtins.filter (n: entries.${n} == "directory") (builtins.attrNames entries);

  # Detect the primary skill file in a directory
  mainFile = dir:
    let dirEntries = builtins.readDir dir;
    in
    if dirEntries ? "SKILL.md" then "SKILL.md"
    else if dirEntries ? "index.md" then "index.md"
    else builtins.throw "No SKILL.md or index.md in ${builtins.toString dir}";

  # Read the first line to decide if frontmatter already exists
  hasFrontmatter = file:
    let content = builtins.readFile file;
        firstLine = builtins.head (builtins.split "\n" content);
    in firstLine == "---";

  # Extract name and description from a "# Name — Description" heading
  extractMeta = file:
    let
      content = builtins.readFile file;
      lines = builtins.filter builtins.isString (builtins.split "\n" content);
      firstNonEmpty = builtins.head (builtins.filter (l: l != "" && l != " ") lines);
      # Strip "# " prefix
      stripped = lib.removePrefix "# " firstNonEmpty;
      # Split on " — " (em-dash) or " - "
      parts =
        if builtins.match ".*—.*" stripped != null
        then builtins.split " — " stripped
        else builtins.split " - " stripped;
      textParts = builtins.filter builtins.isString parts;
      name = builtins.head textParts;
      desc = if builtins.length textParts > 1
             then builtins.elemAt textParts 1
             else stripped;
    in { inherit name desc; };
in
pkgs.runCommand "desktop-skills" {
  nativeBuildInputs = [ pkgs.zip ];
} (
  let
    # For each skill, generate shell commands to build and zip
    perSkill = name:
      let
        srcDir = skillsDir + "/${name}";
        mf = mainFile srcDir;
        srcFile = srcDir + "/${mf}";
        hasFM = hasFrontmatter srcFile;
        meta = if hasFM then null else extractMeta srcFile;
      in ''
        echo "Packaging: ${name}"
        mkdir -p work/${name}

        # Copy all files from skill directory
        cp -R ${srcDir}/. work/${name}/

        # Rename main file to Skill.md (Desktop convention)
        # Two-step rename avoids macOS case-insensitive FS collision (SKILL.md → Skill.md)
        ${if mf != "Skill.md" then ''
          mv work/${name}/${mf} work/${name}/_skill_tmp.md
          mv work/${name}/_skill_tmp.md work/${name}/Skill.md
        '' else ""}

        ${if !hasFM then ''
          # Inject YAML frontmatter
          tmp=$(mktemp)
          {
            echo "---"
            echo 'name: "${meta.name}"'
            echo 'description: "${meta.desc}"'
            echo "---"
            echo ""
            cat work/${name}/Skill.md
          } > "$tmp"
          mv "$tmp" work/${name}/Skill.md
        '' else ""}

        # Create ZIP: <name>.zip containing <name>/Skill.md + resources
        (cd work && zip -r "$out/${name}.zip" "${name}")
      '';
  in ''
    mkdir -p $out work
    ${builtins.concatStringsSep "\n" (map perSkill skillNames)}
    echo ""
    echo "=== Built ${builtins.toString (builtins.length skillNames)} skill ZIPs ==="
    ls -lh $out/*.zip
  ''
)
