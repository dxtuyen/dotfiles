{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage {
  pname = "wifui";
  version = "0.6.0-unstable-2026-10-31";

  src = fetchFromGitHub {
    owner = "sohamw03";
    repo = "wifui";
    rev = "fa862d07bb97b10a7017bc5c0f6ea9f7d0abac80";
    hash = "sha256-QGK4l5MEqAiGbxKaeSb36j3J79g4/+0+6d8KnNC1CKM=";
  };
  cargoHash = "sha256-UQHJ5d78GRWG8ufKSFF8gFvP6TG/Fxg8vAkzj+/3al0=";

  # This UI test discovers a live Wi-Fi backend, unavailable in the Nix sandbox.
  checkFlags = [ "--skip=ui::tests::hover_fills_whole_row_width" ];

  meta = {
    description = "Keyboard-driven Wi-Fi manager for the terminal";
    homepage = "https://github.com/sohamw03/wifui";
    license = lib.licenses.mit;
    mainProgram = "wifui";
    platforms = lib.platforms.linux;
  };
}
