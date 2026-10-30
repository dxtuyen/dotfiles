{ ... }:

let
  theme = import ../theme.nix;
in

{
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    focusEvents = true;
    mouse = true;
    baseIndex = 1;
    historyLimit = 10000;
    keyMode = "vi";
    clock24 = true;

    extraConfig = ''
      # Foot advertises RGB outside tmux; applications use tmux-256color inside.
      set -as terminal-features ',foot*:RGB'
      set -g renumber-windows on

      # New shells follow the pane's working directory (also used by Bash's nt).
      bind c new-window -c '#{pane_current_path}'
      bind '"' split-window -v -c '#{pane_current_path}'
      bind % split-window -h -c '#{pane_current_path}'

      # Prefix-based navigation leaves LazyVim's Ctrl+h/j/k/l available.
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      set -g status-style 'bg=${theme.bg1},fg=${theme.fg1}'
      set -g status-left '#[fg=${theme.green},bold] #S #[default]'
      set -g status-right '#[fg=${theme.gray}] %H:%M '
      setw -g window-status-current-style 'bg=${theme.selection},fg=${theme.yellow},bold'
      set -g pane-border-style 'fg=${theme.bg3}'
      set -g pane-active-border-style 'fg=${theme.blue}'
      set -g message-style 'bg=${theme.bg2},fg=${theme.fg0}'
    '';
  };
}
