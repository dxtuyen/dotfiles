{ pkgs, ... }:

{
  home.file.".local/bin/obsidian-toggle" = {
    executable = true;
    text = ''
      #!${pkgs.python3}/bin/python3
      # Focus Obsidian, restore it from the scratchpad, hide it, or launch it.
      import json
      import re
      import shutil
      import subprocess
      import sys

      swaymsg = shutil.which("swaymsg")
      if not swaymsg:
          sys.exit("obsidian-toggle: swaymsg is not in PATH")

      tree = json.loads(subprocess.run(
          [swaymsg, "-t", "get_tree"], check=True, capture_output=True, text=True
      ).stdout)

      app_id_pattern = re.compile(r"(?:md(?:\.obsidian)?\.obsidian|obsidian)", re.I)

      def is_obsidian(node):
          properties = node.get("window_properties") or {}
          identities = (node.get("app_id"), properties.get("class"))
          return any(
              identity and app_id_pattern.fullmatch(identity)
              for identity in identities
          )

      def find_obsidian(node):
          if is_obsidian(node):
              yield node
          for key in ("nodes", "floating_nodes"):
              for child in node.get(key, []):
                  yield from find_obsidian(child)

      matches = list(find_obsidian(tree))
      if not matches:
          subprocess.Popen(
              ["${pkgs.obsidian}/bin/obsidian"],
              stdin=subprocess.DEVNULL,
              stdout=subprocess.DEVNULL,
              stderr=subprocess.DEVNULL,
              start_new_session=True,
          )
          sys.exit(0)

      window = next((item for item in matches if item.get("focused")), None)
      if window is None:
          window = next((item for item in matches if item.get("visible")), matches[0])

      criteria = f"[con_id={window['id']}]"
      if window.get("focused"):
          command = (
              "scratchpad show"
              if window.get("scratchpad_state") not in (None, "none")
              else "move container to scratchpad"
          )
          subprocess.run([swaymsg, f"{criteria} {command}"], check=True)
      elif window.get("visible"):
          subprocess.run([swaymsg, f"{criteria} focus"], check=True)
      elif window.get("scratchpad_state") not in (None, "none"):
          subprocess.run([swaymsg, f"{criteria} scratchpad show"], check=True)
      else:
          subprocess.run(
              [swaymsg, f"{criteria} move container to workspace current, focus"],
              check=True,
          )
    '';
  };
}
