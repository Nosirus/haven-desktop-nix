{
  lib,
  stdenv,
  appimageTools,
  fetchurl,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  gtk4,
  nspr,
  nss,
  pango,
  systemd,
  libnotify,
  libsecret,
  libpulseaudio,
  pipewire,
  libdrm,
  libgbm,
  libxkbcommon,
  libxshmfence,
  libGL,
  vulkan-loader,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxtst,
  libxscrnsaver,
  libxkbfile,
  libxcb,
  zenity,
  xdg-utils,
  xdg-user-dirs,
}:

let
  release = builtins.fromJSON (builtins.readFile ./latest.json);

  version = release.version;
  pname = "haven-desktop";

  src = fetchurl {
    url = release.url;
    sha512 = release.sha512;
  };

  appimageContents = appimageTools.extract { inherit pname version src; };

  runtimeLibs = [
    alsa-lib
    at-spi2-atk
    atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    gtk4
    nspr
    nss
    pango
    systemd
    libnotify
    libsecret
    libpulseaudio
    pipewire
    libdrm
    libgbm
    libxkbcommon
    libxshmfence
    libGL
    vulkan-loader
    stdenv.cc.cc
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxtst
    libxscrnsaver
    libxkbfile
    libxcb
  ];

  runtimePath = [
    pipewire
    zenity
    xdg-utils
    xdg-user-dirs
  ];

  libraryPath = lib.makeLibraryPath runtimeLibs;
in
stdenv.mkDerivation {
  inherit pname version;

  src = appimageContents;

  nativeBuildInputs = [
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = runtimeLibs ++ runtimePath;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/haven-desktop
    cp -a ${appimageContents}/. $out/libexec/haven-desktop/
    chmod -R u+w $out/libexec/haven-desktop

    install -Dm644 $out/libexec/haven-desktop/haven-desktop.desktop \
      $out/share/applications/haven-desktop.desktop
    substituteInPlace $out/share/applications/haven-desktop.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=haven-desktop'

    install -Dm644 $out/libexec/haven-desktop/usr/share/icons/hicolor/512x512/apps/haven-desktop.png \
      $out/share/icons/hicolor/512x512/apps/haven-desktop.png

    runHook postInstall
  '';

  preFixup = ''
    patchelf \
      --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      --set-rpath "${libraryPath}:$out/libexec/haven-desktop" \
      $out/libexec/haven-desktop/haven-desktop \
      $out/libexec/haven-desktop/chrome_crashpad_handler

    # Native modules are dlopen()ed, so they need their own RUNPATH
    # (the executable's RUNPATH is not consulted for dlopen dependencies).
    patchelf \
      --set-rpath "${libraryPath}:$out/libexec/haven-desktop" \
      $out/libexec/haven-desktop/resources/native/haven_audio.node
  '';

  postFixup = ''
    makeWrapper $out/libexec/haven-desktop/haven-desktop $out/bin/haven-desktop \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : "${libraryPath}:$out/libexec/haven-desktop" \
      --prefix PATH : "${lib.makeBinPath runtimePath}" \
      --add-flags "--no-sandbox"
  '';

  meta = {
    description = "Haven Desktop — client de chat privé auto-hébergé";
    homepage = "https://github.com/ancsemi/Haven-Desktop";
    license = lib.licenses.agpl3Only;
    mainProgram = "haven-desktop";
    platforms = [ "x86_64-linux" ];
  };
}
