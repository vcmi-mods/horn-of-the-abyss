#!/usr/bin/env python3
"""Install dependencies for a VCMI mod from the vcmi-mods-repository."""

import json
import os
import sys
import urllib.request
import zipfile
import tempfile
import jstyleson
from pathlib import Path


def find_mod_json_files(root: Path) -> list:
    """Find every mod.json below root (case-insensitive)."""
    return sorted(
        (path for path in root.rglob("*") if path.is_file() and path.name.lower() == "mod.json"),
        key=lambda path: path.as_posix().lower(),
    )


def iter_depends_values(data):
    """Yield every depends value from a parsed mod manifest."""
    if isinstance(data, dict):
        for key, value in data.items():
            if key == "depends":
                yield value
            yield from iter_depends_values(value)
    elif isinstance(data, list):
        for item in data:
            yield from iter_depends_values(item)


def normalize_dependency_ids(depends_value) -> set:
    """Return package ids referenced by a depends value."""
    if isinstance(depends_value, str):
        return {depends_value.split(".")[0]}
    if isinstance(depends_value, list):
        return {dep.split(".")[0] for dep in depends_value if isinstance(dep, str)}
    if isinstance(depends_value, dict):
        return {dep.split(".")[0] for dep in depends_value if isinstance(dep, str)}
    return set()


def collect_dependencies(root: Path) -> set:
    deps = set()
    mod_files = find_mod_json_files(root)
    print(f"Scanning {len(mod_files)} mod.json file(s) under {root} ...")
    for mod_file in mod_files:
        with open(mod_file) as f:
            data = jstyleson.load(f)
        file_deps = set()
        for depends_value in iter_depends_values(data):
            file_deps.update(normalize_dependency_ids(depends_value))
        if file_deps:
            print(f"  {mod_file.relative_to(root)}: {', '.join(sorted(file_deps))}")
        deps.update(file_deps)
    return deps


def download_and_install(dep_id: str, download_url: str, install_dir: Path) -> None:
    dest = install_dir / dep_id
    if dest.exists():
        print(f"  {dep_id}: already installed, skipping")
        return

    print(f"  {dep_id}: downloading from {download_url}")
    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp_zip = Path(tmp_dir) / f"{dep_id}.zip"
        urllib.request.urlretrieve(download_url, str(tmp_zip))

        extract_dir = Path(tmp_dir) / "extracted"
        extract_dir.mkdir()
        with zipfile.ZipFile(tmp_zip) as zf:
            zf.extractall(extract_dir)

        entries = list(extract_dir.iterdir())
        if len(entries) == 1 and entries[0].is_dir():
            entries[0].rename(dest)
        else:
            extract_dir.rename(dest)

    print(f"  {dep_id}: installed to {dest}")


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: install_mod_dependencies.py <branch> [install_dir] [root]", file=sys.stderr)
        sys.exit(1)

    branch = sys.argv[1]
    install_dir = Path.home() / ".local/share/vcmi/Mods"
    root = Path.cwd()

    if len(sys.argv) > 2:
        install_dir = Path(sys.argv[2])
    if len(sys.argv) > 3:
        root = Path(sys.argv[3])

    repo_url = (
        f"https://raw.githubusercontent.com/vcmi/vcmi-mods-repository"
        f"/refs/heads/develop/{branch}.json"
    )
    print(f"Downloading mod repository from {repo_url} ...")
    with urllib.request.urlopen(repo_url) as resp:
        repo = json.loads(resp.read())

    available_mods = repo.get("availableMods", {})

    deps = collect_dependencies(root)
    if not deps:
        print("No dependencies found.")
        return

    print(f"Found dependencies: {', '.join(sorted(deps))}")
    install_dir.mkdir(parents=True, exist_ok=True)

    for dep_id in sorted(deps):
        if dep_id not in available_mods:
            print(f"  {dep_id}: not found in repository, skipping")
            continue
        download_url = available_mods[dep_id].get("download")
        if not download_url:
            print(f"  {dep_id}: no download URL, skipping")
            continue
        download_and_install(dep_id, download_url, install_dir)

    print("Dependency installation complete.")


if __name__ == "__main__":
    main()
