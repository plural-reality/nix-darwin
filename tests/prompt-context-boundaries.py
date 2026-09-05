from functools import reduce
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROMPT_ROOT = ROOT / "prompt"
MACROS = {
    f"@[{path.stem}]": path.read_text()
    for path in PROMPT_ROOT.glob("*.md")
}
RENDER = lambda path: reduce(
    lambda rendered, item: rendered.replace(*item),
    MACROS.items(),
    path.read_text(),
)
RENDERED = {
    "codex": RENDER(PROMPT_ROOT / "codex" / "agent.md"),
    "claude": RENDER(PROMPT_ROOT / "claude-code" / "claude.md"),
}
REQUIRED = (
    "外部メッセージ",
    "canonical readback",
    "agent-tooling-safety",
    "browser-automation",
    "apple-calendar",
    "repo固有",
)

assert all("@[" not in prompt for prompt in RENDERED.values())
assert all(len(prompt.encode()) <= 9000 for prompt in RENDERED.values())
assert all(
    requirement in prompt
    for requirement in REQUIRED
    for prompt in RENDERED.values()
)
assert "clarify-and-build" not in RENDERED["codex"]
assert "~/.claude/scripts/pw.mjs" in (PROMPT_ROOT / "claude-code" / "skills" / "browser-automation" / "SKILL.md").read_text()
assert "実行しない" in (PROMPT_ROOT / "claude-code" / "skills" / "browser-automation" / "SKILL.md").read_text()
