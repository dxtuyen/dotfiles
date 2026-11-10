"""Verify the generated session transaction without accessing a live manager."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    units, system_units, engine = map(Path, sys.argv[1:])
    with tempfile.TemporaryDirectory(prefix="session-units-") as directory:
        home = Path(directory)
        command = home / ".local/bin/countdown-engine"
        command.parent.mkdir(parents=True)
        command.symlink_to(engine)
        env = dict(
            os.environ,
            HOME=directory,
            XDG_RUNTIME_DIR=directory,
            XDG_CONFIG_HOME=str(home / "config"),
            XDG_DATA_HOME=str(home / "data"),
            SYSTEMD_UNIT_PATH=f"{units}:{system_units}",
        )
        # Include the generated .wants symlinks through SYSTEMD_UNIT_PATH so
        # target subscriptions and ordering cycles are checked too.
        subprocess.run(
            ["systemd-analyze", "--user", "verify", "--man=no", "--generators=no",
             *[str(path) for path in sorted(units.iterdir()) if path.is_file()]],
            env=env, check=True, timeout=30,
        )


if __name__ == "__main__":
    main()
