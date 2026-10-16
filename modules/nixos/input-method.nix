{
  config,
  inputs,
  lib,
  pkgs,
  userName,
  ...
}:

let
  fcitxPackage = config.i18n.inputMethod.package;
  fcitxAddons = config.i18n.inputMethod.fcitx5.addons;
  fcitxAddonDirs = lib.makeSearchPath "lib/fcitx5" fcitxAddons;
  fcitxDataDirs = lib.makeSearchPath "share/fcitx5" fcitxAddons;

  # Keep the source and derivation version aligned with the pinned release.
  lotusPackage =
    inputs.lotus.packages.${pkgs.stdenv.hostPlatform.system}.fcitx5-lotus.overrideAttrs
      (_: {
        version = "5.0.4";
        src = pkgs.fetchFromGitHub {
          owner = "LotusInputMethod";
          repo = "fcitx5-lotus";
          tag = "v5.0.4";
          hash = "sha256-E1A9PviA9V4I8f/3iLsiLA1nb4EM+nh+WG8sXwbudCA=";
        };
      });
in
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [ fcitx5-gtk ];
  };

  # Lotus uses uinput for direct key replacement without preedit.
  boot.kernelModules = [ "uinput" ];
  services.fcitx5-lotus = {
    enable = true;
    users = [ userName ];
    package = lotusPackage;
  };

  environment.sessionVariables = {
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
  };

  # Fcitx ignores addon metadata exposed as buildEnv symlinks, so provide the
  # individual addon directories in the session service environment.
  systemd.user.services.fcitx5-daemon = {
    description = "Fcitx5 input method daemon";
    wantedBy = [ "sway-session.target" ];
    partOf = [ "sway-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${fcitxPackage}/bin/fcitx5";
      Environment = [
        "FCITX_ADDON_DIRS=${fcitxAddonDirs}:${fcitxPackage}/lib/fcitx5"
        "FCITX_DATA_DIRS=${fcitxDataDirs}:${fcitxPackage}/share/fcitx5"
      ];
      Restart = "on-failure";
      RestartSec = "2";
    };
  };
}
