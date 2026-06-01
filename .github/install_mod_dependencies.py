#!/usr/bin/env python3
"""Install dependencies for a VCMI mod from the vcmi-mods-repository."""

import json
import os
import sys
import urllib.request
import zipfile
import tempfile
from pathlib import Path


def find_mod_json_files(root: Path) -> list:
    """Find mod.json in root and in Mods/*/mod.json (case-insensitive)."""
    results = []
    for entry in root.iterdir():
        if entry.is_file() and entry.name.lower() == "mod.json":
            results.append(entry)
    for entry in root.iterdir():
        if entry.is_dir() and entry.name.lower() == "mods":
            for subdir in entry.iterdir():
                if subdir.is_dir():
                    for f in subdir.iterdir():
                        if f.is_file() and f.name.lower() == "mod.json":
                            results.append(f)
    return results


def collect_dependencies(root: Path) -> set:
    deps = set()
    for mod_file in find_mod_json_files(root):
        with open(mod_file) as f:
            data = json.load(f)
        for dep in data.get("depends", []):
            deps.add(dep.split(".")[0])
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
    branch = os.environ.get("GITHUB_REF_NAME", "vcmi-1.7")
    install_dir = Path.home() / ".local/share/vcmi/Mods"
    root = Path.cwd()

    if len(sys.argv) > 1:
        branch = sys.argv[1]
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
