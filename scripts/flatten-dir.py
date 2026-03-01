#!/usr/bin/env python3
# ==============================================================================
# Flatten Directory Script
# Purpose: Flattens a nested directory structure into a single directory.
# Useful for preparing data for LLMs/NotebookLM that don't handle folders well.
# Strategy: Replaces path separators with '__' to preserve context and avoid naming collisions.
# ==============================================================================

import sys
import shutil
import os
from pathlib import Path

def flatten_copy(src: Path, dest: Path):
    """
    Recursively copies files from src to dest, flattening the hierarchy.
    Renames files: 'subdir/file.txt' -> 'subdir__file.txt'
    """
    if not src.exists():
        sys.stderr.write(f"Error: Source '{src}' does not exist.\n")
        sys.exit(1)

    if not src.is_dir():
        sys.stderr.write(f"Error: Source '{src}' is not a directory.\n")
        sys.exit(1)

    # Create destination (Side effect)
    dest.mkdir(parents=True, exist_ok=True)

    # Pure-ish generation of copy tasks
    # Filter out hidden files like .DS_Store
    files = (
        p for p in src.rglob('*')
        if p.is_file() and not p.name.startswith('.')
    )

    count = 0
    for p in files:
        try:
            # Create a flat name preserving hierarchy
            rel_path = p.relative_to(src)
            # Replace / with __ (Platform agnostic enough for this use case)
            # e.g., "docs/v1/api.md" -> "docs__v1__api.md"
            flat_name = str(rel_path).replace(os.sep, '__')

            target = dest / flat_name

            # Perform copy (preserving metadata)
            shutil.copy2(p, target)
            print(f"cp '{rel_path}' -> '{target.name}'")
            count += 1
        except Exception as e:
            sys.stderr.write(f"Failed to copy {p}: {e}\n")

    print(f"\nSuccessfully flattened {count} files to '{dest}'.")

def main():
    if len(sys.argv) != 3:
        print("Usage: flatten-dir <SRC_DIR> <DEST_DIR>")
        print("Example: flatten-dir ./my-docs ./flat-docs")
        sys.exit(1)

    src_dir = Path(sys.argv[1]).resolve()
    dest_dir = Path(sys.argv[2]).resolve()

    flatten_copy(src_dir, dest_dir)

if __name__ == "__main__":
    main()
