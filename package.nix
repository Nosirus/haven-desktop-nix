{ lib, appimageTools, fetchurl, makeWrapper, haven-latest }:

let
  yml = builtins.readFile haven-latest;

  parsed = builtins.match ".*version: ([^\n]+).*path: ([^\n]+)\nsha512: ([^\n]+).*" yml;

  version = builtins.elemAt parsed 0;
  appimageName = builtins.elemAt parsed 1;
  sha512 = builtins.elemAt parsed 2;

  pname = "haven-desktop";

  src = fetchurl {
    url = "https://github.com/ancsemi/Haven-Desktop/releases/download/v${version}/${appimageName}";
    inherit sha512;
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  extraInstallCommands = ''
    set -- ${appimageContents}/*.desktop
    install -Dm444 "$1" $out/share/applications/haven-desktop.desktop
    substituteInPlace $out/share/applications/haven-desktop.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=haven-desktop' || true

    set -- ${appimageContents}/*.png
    if [ -e "$1" ]; then
      install -Dm444 "$1" $out/share/icons/hicolor/256x256/apps/haven-desktop.png
    fi

    wrapProgram $out/bin/haven-desktop --add-flags "--no-sandbox"
  '';

  meta = {
    description = "Haven Desktop — client de chat privé auto-hébergé";
    homepage = "https://github.com/ancsemi/Haven-Desktop";
    license = lib.licenses.agpl3Only;
    mainProgram = "haven-desktop";
    platforms = [ "x86_64-linux" ];
  };
}
