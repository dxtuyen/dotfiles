{ pkgs, ... }:

# Starship: just path + git + long-running commands + the ❯ character.

{
  programs.starship = {
    enable = true;
    # Integrate the prompt with Bash.
    enableBashIntegration = true;

    settings = {
      # Blank line between prompts (Starship default).
      add_newline = true;

      # Line 1: path + git + command time; line 2: ❯.
      format = "$directory$git_branch$git_status$cmd_duration\n$character";

      directory = {
        # Catppuccin Mocha blue
        style = "bold #89b4fa";
        read_only_style = "#f38ba8";
        truncation_length = 3;
        truncate_to_repo = true;
        home_symbol = "~";
        format = "[$path]($style)[$read_only]($read_only_style) ";
      };

      git_branch = {
        symbol = "";
        style = "#cba6f7";
        format = "[$symbol$branch]($style) ";
      };

      git_status = {
        format = "([$all_status$ahead_behind]($style) )";
        style = "#6c7086";

        modified = "[✱](#fab387)";
        deleted = "[✖](#f38ba8)";
        untracked = "[?](#89b4fa)";
        renamed = "[»](#cba6f7)";
        conflicted = "[=](#f38ba8)";

        # Hide rarely used statuses to keep the prompt short.
        stashed = "";
        ahead = "";
        behind = "";
        diverged = "";
        typechanged = "";
      };

      cmd_duration = {
        min_time = 2000; # only show when a command runs >= 2s
        style = "#fab387";
        format = "[ $duration]($style) ";
      };

      character = {
        success_symbol = "[❯](bold #a6e3a1)";
        error_symbol = "[❯](bold #f38ba8)";
        vicmd_symbol = "[❮](bold #94e2d5)";
      };
    };
  };
}
