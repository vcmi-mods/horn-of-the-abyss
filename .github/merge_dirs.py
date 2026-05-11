#!/usr/bin/env python3
import os
import shutil
import tempfile
from pathlib import Path

def merge_directories_overwrite(source_dir, dest_dir):
    """
    Merge source_dir into dest_dir with case-insensitive handling (files & dirs).
    Overwrite mode: source files replace destination files when names match
    case-insensitively. Directory-to-directory conflicts result in recursive merge.
    
    Assumptions: 
    - Linux, ASCII filenames, no symlinks, writable directories
    - Only dir-vs-dir conflicts (merge) and file-vs-file conflicts (overwrite) occur
    - Dir-vs-file conflicts are illegal and will raise an exception
    
    Returns True on success, False on error.
    """
    source_path = Path(source_dir)
    dest_path = Path(dest_dir)

    # Basic checks
    if not source_path.exists() or not source_path.is_dir():
        print(f"Error: source '{source_dir}' does not exist or is not a directory")
        return False

    # Prevent dest inside source or source inside dest
    if dest_path.resolve().is_relative_to(source_path.resolve()):
        print("Error: destination is inside source (not supported)")
        return False
    if source_path.resolve().is_relative_to(dest_path.resolve()):
        print("Error: source is inside destination (not supported)")
        return False

    # Ensure destination exists
    dest_path.mkdir(parents=True, exist_ok=True)

    # Cache for directory listings to avoid repeated os.listdir calls
    list_cache = {}  # Path -> dict(lower_name -> actual_name)

    def get_listing_map(dir_path: Path):
        dir_path = dir_path.resolve()
        if dir_path in list_cache:
            return list_cache[dir_path]
        entries = {}
        for name in os.listdir(dir_path):
            entries[name.lower()] = name
        list_cache[dir_path] = entries
        return entries

    def ensure_target_dir(relative_parts):
        """
        Walk/create the chain of directories under dest_path for the given relative parts.
        Returns the Path to the target directory.
        
        Raises FileExistsError if a file exists where a directory is expected.
        """
        current = dest_path
        for part in relative_parts:
            lm = get_listing_map(current)
            part_lower = part.lower()
            if part_lower in lm:
                # Case-insensitive match found; must be a directory
                current = current / lm[part_lower]
            else:
                # No match; create directory with source casing
                new_dir = current / part
                new_dir.mkdir(parents=False)
                # update cache for parent and new dir
                list_cache.pop(current.resolve(), None)
                list_cache.pop(new_dir.resolve(), None)
                current = new_dir
        return current

    # Walk source directory recursively
    for root, _, files in os.walk(source_path):
        root_path = Path(root)
        rel = root_path.relative_to(source_path)
        parts = rel.parts if rel.parts != () else ()
        target_dir = ensure_target_dir(parts)

        # Prepare listing map for the target directory
        target_map = get_listing_map(target_dir)

        for file_name in files:
            file_lower = file_name.lower()
            source_file = root_path / file_name

            if file_lower in target_map:
                # Case-insensitive match found; must be a file (overwrite)
                existing_name = target_map[file_lower]
                target_file = target_dir / existing_name
                print(f"Overwriting: {target_file.relative_to(dest_path)}")
            else:
                # No conflict; create with source casing
                target_file = target_dir / file_name
                print(f"Creating: {target_file.relative_to(dest_path)}")

            shutil.copy2(source_file, target_file) 
            list_cache.pop(target_dir.resolve(), None)

    return True


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 3:
        print("Usage: python merge_dirs.py <source_dir> <dest_dir>")
        sys.exit(1)
    ok = merge_directories_overwrite(sys.argv[1], sys.argv[2])
    sys.exit(0 if ok else 2)
