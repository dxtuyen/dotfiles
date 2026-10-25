{ pkgs, ... }:

let
  theme = import ../theme.nix;
in

# A compact two-line prompt using the shared Gruvbox palette.

{
  programs.starship = {
    enable = true;
    # Integrate the prompt with Bash.
    enableBashIntegration = true;

    settings = {
      # Separate prompts so command history is easier to scan.
      add_newline = true;

      # Keep the context and prompt aligned at the left edge.
      format = "$directory$git_branch$git_status$cmd_duration\n$character";

      directory = {
        style = "bold ${theme.blue}";
        read_only_style = theme.red;
        truncation_length = 3;
        truncate_to_repo = true;
        home_symbol = "~";
        format = "[$path]($style)[$read_only]($read_only_style) ";
      };

      git_branch = {
        symbol = " ";
        style = theme.purple;
        format = "[$symbol$branch]($style) ";
      };

      git_status = {
        format = "([$all_status$ahead_behind]($style) )";
        style = theme.gray;

        modified = "[✱](${theme.yellow})";
        deleted = "[✖](${theme.red})";
        untracked = "[?](${theme.blue})";
        renamed = "[»](${theme.purple})";
        conflicted = "[=](${theme.red})";

        # Hide rarely used statuses to keep the prompt short.
        stashed = "";
        ahead = "";
        behind = "";
        diverged = "";
        typechanged = "";
      };

      cmd_duration = {
        min_time = 2000; # only show when a command runs >= 2s
        style = theme.orange;
        format = "[ $duration]($style) ";
      };

      character = {
        success_symbol = "[❯](bold ${theme.green})";
        error_symbol = "[❯](bold ${theme.red})";
        vicmd_symbol = "[❮](bold ${theme.aqua})";
      };
    };
  };
}
