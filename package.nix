{ lib, stdenv, fetchFromGitHub, makeWrapper, electron
, nodejs, python3, pkg-config, libpulseaudio, cacert
, src ? null }:

let
  source = if src != null then src else fetchFromGitHub {
    owner = "ancsemi";
    repo = "Haven-Desktop";
    rev = "v1.4.30";
    hash = lib.fakeHash;
  };

  version = (builtins.fromJSON (builtins.readFile "${source}/package.json")).version;

  npmDeps = stdenv.mkDerivation {
    pname = "haven-desktop-npm-deps";
    inherit version;
    src = source;
    nativeBuildInputs = [ nodejs cacert ];

    buildPhase = ''
      runHook preBuild
      export HOME="$TMPDIR"
      export npm_config_cache="$TMPDIR/npm-cache"
      export npm_config_cafile="${cacert}/etc/ssl/certs/ca-bundle.crt"
      export NODE_EXTRA_CA_CERTS="${cacert}/etc/ssl/certs/ca-bundle.crt"
      npm install --ignore-scripts --omit=dev --omit=optional --no-audit --no-fund
      mkdir -p "$out"
      cp -r node_modules "$out/node_modules"
      runHook postBuild
    '';

    outputHashMode = "recursive";
    outputHash = "sha256-tR3LqklntvMZWCiNlK1hyXBRoKqeWsRAOWFqeiDZlNc=";
  };
in

stdenv.mkDerivation (finalAttrs: {
  pname = "haven-desktop";
  inherit version;

  src = source;

  nativeBuildInputs = [ makeWrapper nodejs python3 pkg-config ];
  buildInputs = [ libpulseaudio ];

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR"
    export npm_config_python="${python3}/bin/python3"

    cp -r "${npmDeps}/node_modules" node_modules

    "${nodejs}/bin/node" \
      "${nodejs}/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js" \
      rebuild --directory=native --nodedir="${nodejs}"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    app="$out/lib/haven-desktop"
    mkdir -p "$app" "$out/bin"
    cp -rT src "$app/src"
    cp -r assets "$app/assets"
    cp -r node_modules "$app/node_modules"
    cp -r native/build/Release "$app/native"
    cp package.json package-lock.json "$app/"

    makeWrapper "${electron}/bin/electron" "$out/bin/haven-desktop" \
      --add-flags "$app" \
      --add-flags "--no-sandbox" \
      --set ELECTRON_IS_DEV 0 \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libpulseaudio ]}"

    mkdir -p "$out/share/applications" \
             "$out/share/icons/hicolor/256x256/apps" \
             "$out/share/icons/hicolor/scalable/apps"
    cp assets/icon.png "$out/share/icons/hicolor/256x256/apps/haven-desktop.png"
    cat > "$out/share/applications/haven-desktop.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Haven
GenericName=Chat Client
Comment=Private self-hosted chat
Exec=haven-desktop
Icon=haven-desktop
Terminal=false
Categories=Network;Chat;InstantMessaging;
EOF

    runHook postInstall
  '';

  meta = {
    description = "Haven Desktop — private, self-hosted chat client";
    homepage = "https://ancsemi.github.io/Haven/";
    license = lib.licenses.agpl3Only;
    mainProgram = "haven-desktop";
    platforms = lib.platforms.linux;
  };
})