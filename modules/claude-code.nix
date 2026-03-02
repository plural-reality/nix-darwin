# Managed dotfiles: Claude Code, Gemini, Cursor
{ pkgs, lib, ... }:
let
  expandTemplate = import ../lib/expand-template.nix { inherit lib; };
  expandTemplatesDir = import ../lib/expand-templates-dir.nix { inherit pkgs lib; };
in
{
  home.file =
    {
      # Gemini
      ".gemini/GEMINI.md".text = expandTemplate {
        templateScope = ../prompt;
        template = ../prompt/antigravity.md;
      };

      # Claude Code
      ".claude/CLAUDE.md".text = expandTemplate {
        templateScope = ../prompt;
        template = ../prompt/claude-code/claude.md;
      };
      ".claude/settings.json".text = builtins.toJSON {
        env = {
          CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
        };
        teammateMode = "tmux";
        permissions = {
          allow = [
            "Bash(grep:*)"
            "Bash(find:*)"
            "Bash(cat:*)"
            "Bash(ls:*)"
            "Bash(head:*)"
            "Bash(tail:*)"
            "Bash(wc:*)"
            "Bash(sed:*)"
            "Bash(rg:*)"
            "Bash(fd:*)"
            "Bash(tree:*)"
            "Bash(echo:*)"
            "Bash(git log*)"
            "Bash(git diff*)"
            "Bash(git status*)"
            "Bash(git show*)"
            "Read"
            "Write"
            "WebSearch"
            "WebFetch"
          ];
        };
      };

      # Cursor
      ".cursorrules".text = expandTemplate {
        templateScope = ../prompt;
        template = ../prompt/cursor.md;
      };
    }
    // (
      let
        skillsDir = ../prompt/claude-code/skills;
        entries = builtins.readDir skillsDir;
        skillNames = builtins.filter (name: entries.${name} == "directory") (
          builtins.attrNames entries
        );
      in
      builtins.listToAttrs (
        map (name: {
          name = ".claude/skills/${name}";
          value.source = expandTemplatesDir {
            templateScope = ../prompt;
            src = skillsDir + "/${name}";
          };
        }) skillNames
      )
    );
}
