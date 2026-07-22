#!/usr/bin/env python3
"""Install dependencies for a VCMI mod from the vcmi-mods-repository."""

import json
import sys
import urllib.request
import zipfile
import tempfile
from pathlib import Path

from mod_metadata_common import find_files_ci, load_jsonc


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
    # A list yields its items; a dict yields its keys - both are dependency ids.
    if isinstance(depends_value, (list, dict)):
        return {dep.split(".")[0] for dep in depends_value if isinstance(dep, str)}
    return set()


def collect_dependencies(root: Path) -> set:
    deps = set()
    mod_files = find_files_ci(root, "mod.json")
    print(f"Scanning {len(mod_files)} mod.json file(s) under {root} ...")
    for mod_file in mod_files:
        data = load_jsonc(mod_file)
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


def resolve_dependencies(direct: set, deps_of) -> set:
    """
    Breadth-first walk over the dependency graph, calling deps_of(id) once per mod.

    deps_of(id) installs the mod and returns its own dependencies (a set), or None
    when the mod is unavailable. Cycles terminate because each id is visited once.
    Returns the set of visited ids.
    """
    seen = set()
    queue = sorted(direct)
    while queue:
        dep_id = queue.pop(0)
        if dep_id in seen:
            continue
        seen.add(dep_id)
        children = deps_of(dep_id)
        if children:
            queue.extend(sorted(c for c in children if c not in seen))
    return seen


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

    direct = collect_dependencies(root)
    if not direct:
        print("No dependencies found.")
        return

    print(f"Direct dependencies: {', '.join(sorted(direct))}")
    install_dir.mkdir(parents=True, exist_ok=True)

    def deps_of(dep_id: str):
        if dep_id not in available_mods:
            print(f"  {dep_id}: not found in repository, skipping")
            return None
        download_url = available_mods[dep_id].get("download")
        if not download_url:
            print(f"  {dep_id}: no download URL, skipping")
            return None
        download_and_install(dep_id, download_url, install_dir)
        # Recurse into the installed mod so its own dependencies are pulled in too.
        return collect_dependencies(install_dir / dep_id)

    resolve_dependencies(direct, deps_of)
    print("Dependency installation complete.")


if __name__ == "__main__":
    main()
