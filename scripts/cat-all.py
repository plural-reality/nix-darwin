#!/usr/bin/env python3
# ==============================================================================
# Cat All File Script
# Purpose: Concatenates all text files in the current directory and subdirectories.
# Usage: cat-all (prints to stdout)
# Useful for creating context for LLMs.
# ==============================================================================

import os
import sys
from pathlib import Path

# Files/Dirs to ignore
IGNORE_DIRS = {
    ".git", ".svn", ".hg", "__pycache__", "node_modules",
    ".venv", "venv", "env", ".idea", ".vscode", "dist", "build",
    "result"
}
IGNORE_FILES = {
    ".DS_Store", "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
    "secrets.yaml", "secrets.yaml.plain"
}
IGNORE_EXTS = {
    ".pyc", ".pyo", ".pyd", ".so", ".dll", ".dylib", ".exe", ".bin",
    ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tiff", ".ico", ".svg",
    ".mp3", ".mp4", ".mov", ".wav", ".avi", ".mkv",
    ".zip", ".tar", ".gz", ".7z", ".rar", ".pdf",
    ".woff", ".woff2", ".ttf", ".eot", ".otf"
}

def is_text_file(path_obj):
    """Simple heuristic to check if file is text."""
    if path_obj.suffix.lower() in IGNORE_EXTS:
        return False
    # Identify obvious binary files?
    # For now, just rely on extensions and try scanning the first chunk
    try:
        with open(path_obj, 'rb') as f:
            chunk = f.read(1024)
            if b'\0' in chunk:
                return False
    except:
        return False
    return True

def main():
    root = Path.cwd()

    # Walk directory
    for dirpath, dirnames, filenames in os.walk(root):
        # Modify dirnames in-place to prune ignored directories
        dirnames[:] = [d for d in dirnames if d not in IGNORE_DIRS and not d.startswith('.')]

        path_obj_dir = Path(dirpath)

        for name in sorted(filenames):
            if name in IGNORE_FILES or name.startswith('.'):
                continue

            p = path_obj_dir / name

            if not is_text_file(p):
                continue

            rel_path = p.relative_to(root)

            # Print Header
            print(f"--- {rel_path} ---")

            # Print Content
            try:
                # Try reading as UTF-8
                print(p.read_text(encoding='utf-8', errors='replace'))
            except Exception as e:
                print(f"[Error reading file: {e}]")

            print() # Empty line delimiter

if __name__ == "__main__":
    main()
