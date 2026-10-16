{
  config,
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

  cfg = config.services.fcitx5-lotus;

  lotusPython = pkgs.python3.withPackages (
    ps: with ps; [
      dbus-python
      pyqt6
      qtpy
    ]
  );

  lotusPackage = pkgs.stdenv.mkDerivation {
    pname = "fcitx5-lotus";
    version = "5.0.4";

    src = pkgs.fetchFromGitHub {
      owner = "LotusInputMethod";
      repo = "fcitx5-lotus";
      tag = "v5.0.4";
      hash = "sha256-E1A9PviA9V4I8f/3iLsiLA1nb4EM+nh+WG8sXwbudCA=";
    };

    nativeBuildInputs = with pkgs; [
      cmake
      gettext
      hicolor-icon-theme
      kdePackages.extra-cmake-modules
      pkg-config
      qt6.wrapQtAppsHook
    ];

    buildInputs = with pkgs; [
      acl
      fcitx5
      kdePackages.extra-cmake-modules
      libevdev
      libinput
      lotusPython
      qt6.qtbase
      qt6.qtsvg
      udev
    ];

    strictDeps = true;
    __structuredAttrs = true;
    dontWrapQtApps = true;

    cmakeFlags = [
      "-DLOTUS_ALT_EXECUTABLE_PREFIX=/nix/store/"
      "-DLOTUS_SETFACL_EXECUTABLE=${pkgs.acl}/bin/setfacl"
    ];

    postFixup = ''
      patchShebangs $out/share/fcitx5-lotus/settings-gui
      wrapQtApp $out/bin/fcitx5-lotus-settings \
        --prefix XDG_DATA_DIRS : "${pkgs.hicolor-icon-theme}/share"
    '';
  };

  effectiveUsers = lib.unique cfg.users;
  invalidUsers = builtins.filter (
    user: user == "" || builtins.match "[A-Za-z_][A-Za-z0-9_-]*" user == null
  ) effectiveUsers;
  unknownUsers = builtins.filter (user: !(builtins.hasAttr user config.users.users)) effectiveUsers;
in
{
  options.services.fcitx5-lotus = {
    enable = lib.mkEnableOption "Fcitx5 Lotus integration";

    package = lib.mkOption {
      type = lib.types.package;
      default = lotusPackage;
      description = "The Fcitx5 Lotus package to install.";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ userName ];
      description = "Users for whom to start a Lotus server.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = effectiveUsers != [ ];
          message = "services.fcitx5-lotus.users must contain at least one user.";
        }
        {
          assertion = invalidUsers == [ ];
          message = "services.fcitx5-lotus.users contains an invalid Linux username.";
        }
        {
          assertion = unknownUsers == [ ];
          message = "services.fcitx5-lotus.users must contain declared users.";
        }
      ];

      i18n.inputMethod.fcitx5.addons = [ cfg.package ];

      users.users.uinput_proxy = {
        isSystemUser = true;
        group = "input";
      };

      services.udev.packages = [ cfg.package ];
      systemd.packages = [ cfg.package ];
      systemd.targets.multi-user.wants = map (user: "fcitx5-lotus-server@${user}.service") effectiveUsers;
    })
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
  ];
}
