{
  lib,
  stdenv,
  acl,
  cmake,
  dbus,
  fcitx5,
  fetchFromGitHub,
  gettext,
  hicolor-icon-theme,
  kdePackages,
  libevdev,
  libinput,
  libnotify,
  pkg-config,
  python3,
  qt6,
  udev,
}:

let
  pythonEnv = python3.withPackages (
    ps: with ps; [
      dbus-python
      pyqt6
      qtpy
    ]
  );
in
stdenv.mkDerivation (finalAttrs: {
  pname = "fcitx5-lotus";
  version = "6.0.4";

  src = fetchFromGitHub {
    owner = "LotusInputMethod";
    repo = "fcitx5-lotus";
    tag = "v${finalAttrs.version}";
    hash = "sha256-d/U2Tu6+mCxmO1QDWU5C54jYLifLh5IO9L9x/lkRPgI=";
  };

  nativeBuildInputs = [
    cmake
    gettext
    hicolor-icon-theme
    kdePackages.extra-cmake-modules
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    acl
    dbus
    fcitx5
    kdePackages.extra-cmake-modules
    libevdev
    libinput
    libnotify
    pythonEnv
    qt6.qtbase
    qt6.qtsvg
    udev
  ];

  strictDeps = true;
  __structuredAttrs = true;
  dontWrapQtApps = true;

  cmakeFlags = [
    "-DLOTUS_ALT_EXECUTABLE_PREFIX=/nix/store/"
    "-DLOTUS_SETFACL_EXECUTABLE=${acl}/bin/setfacl"
  ];

  postFixup = ''
    patchShebangs $out/share/fcitx5-lotus/settings-gui
    wrapQtApp $out/bin/fcitx5-lotus-settings \
      --prefix XDG_DATA_DIRS : "${hicolor-icon-theme}/share"
  '';

  meta = {
    description = "Vietnamese input method engine for Fcitx5";
    homepage = "https://github.com/LotusInputMethod/fcitx5-lotus";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
})
