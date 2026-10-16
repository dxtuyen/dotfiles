{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  libxkbcommon,
  wayland,
  fontconfig,
  freetype,
  stdenv,
}:

stdenvNoCC.mkDerivation {
  pname = "swayview";
  version = "0.1.8";

  src = fetchurl {
    url = "https://github.com/agejevasv/swayview/releases/download/v0.1.8/swayview-v0.1.8-x86_64-linux.tar.gz";
    hash = "sha256:124szx38lxln3i88rqzvai1q69vvvg74mhhz4mqgfj9qg51g1ira";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    libxkbcommon
    wayland
    fontconfig
    freetype
    stdenv.cc.cc.lib
  ];

  sourceRoot = "swayview-v0.1.8-x86_64-linux";
  installPhase = ''
    install -Dm755 swayview $out/bin/swayview
    install -Dm644 LICENSE $out/share/licenses/swayview/LICENSE
  '';

  meta = {
    description = "Workspace overview and switcher for Sway";
    homepage = "https://github.com/agejevasv/swayview";
    license = lib.licenses.mit;
    mainProgram = "swayview";
    platforms = [ "x86_64-linux" ];
  };
}
