"""Install the upstream theme in registered vaults, preserving other settings."""

import json
import os
from pathlib import Path
import shutil
import sys
import tempfile


def apply_theme(registry_path, theme_path):
    registry_path = Path(registry_path)
    if not registry_path.is_file():
        return
    registry = json.loads(registry_path.read_text())
    for vault in registry.get("vaults", {}).values():
        directory = Path(vault["path"]) / ".obsidian"
        if not directory.is_dir():
            continue
        appearance = directory / "appearance.json"
        before = appearance.read_bytes() if appearance.exists() else b"{}"
        settings = json.loads(before)
        settings["cssTheme"] = "Material Gruvbox"
        settings["theme"] = "obsidian"  # Obsidian's dark color scheme.
        updated = (json.dumps(settings, ensure_ascii=False, indent=2) + "\n").encode()

        if os.environ.get("DRY_RUN") is not None:
            print(f"Would apply Gruvbox Material in {directory}")
            continue

        theme_directory = directory / "themes" / "Material Gruvbox"
        theme_directory.mkdir(parents=True, exist_ok=True)
        for name in ("manifest.json", "theme.css"):
            source = Path(theme_path) / name
            target = theme_directory / name
            if target.exists() and target.read_bytes() == source.read_bytes():
                continue
            backup = target.with_name(name + ".before-gruvbox-material")
            if target.exists() and not backup.exists():
                shutil.copy2(target, backup)
            shutil.copyfile(source, target)
        if before == updated:
            continue
        # Don't overwrite settings changed by the running application meanwhile.
        if appearance.exists() and appearance.read_bytes() != before:
            raise RuntimeError(f"Appearance changed during activation: {appearance}")
        backup = appearance.with_name("appearance.json.before-gruvbox-material")
        if appearance.exists() and not backup.exists():
            shutil.copy2(appearance, backup)
        with tempfile.NamedTemporaryFile(dir=directory, delete=False) as temporary:
            temporary.write(updated)
            temporary_path = temporary.name
        os.replace(temporary_path, appearance)


if __name__ == "__main__":
    apply_theme(*sys.argv[1:])
