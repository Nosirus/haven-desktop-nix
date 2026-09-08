# Haven Desktop — build from source for Nix / NixOS (no AppImage, no FUSE).
#
# ── Modes d'utilisation ─────────────────────────────────────────────────────
# 1) Depuis un flake (recommandé, suit les versions de Haven-Desktop) :
#      { pkgs, ... }: {
#        environment.systemPackages = [ pkgs.callPackage ./package.nix { src = <source-du-flake>; } ];
#      }
#    → voir `flake.nix` : la version est lue automatiquement dans le
#      package.json de la source, chaque `nix flake update haven-desktop`
#      te ramène la dernière version publiée.
#
# 2) Sans source fournie (fallback fetchFromGitHub) :
#      { pkgs, ... }: {
#        environment.systemPackages = [ (pkgs.callPackage ./package.nix {}) ];
#      }
#    dont le hash renseigné ci-dessous doit d'abord être rempli :
#      nix-prefetch-url --unpack \
#        https://github.com/ancsemi/Haven-Desktop/archive/refs/tags/v1.4.30.tar.gz
#
# ── Build hors ligne ────────────────────────────────────────────────────────
# Le build tourne ENTIÈREMENT hors ligne une fois la source présente :
#   • les dépendances npm sont pré-téléchargées une seule fois par la
#     dérivation à sortie fixe `npmDeps` (le sandbox Nix autorise le réseau
#     pour les FOD) et cachées dans le store ;
#   • node-gyp compile l'addon audio contre les en-têtes Node embarqués
#     (`--nodedir`), sans aucun téléchargement.
# Aucune option `sandbox=false` ni `trusted-user` n'est nécessaire.
#
# ── Notes ───────────────────────────────────────────────────────────────────
# • L'addon natif audio (native/) est buildé par node-gyp contre les en-têtes
#   *système* de Node ; node-addon-api émet du N-API (ABI stable), le même .node
#   charge donc sous Electron. libpulseaudio est fourni au runtime via
#   LD_LIBRARY_PATH et sa recherche pkg-config passe par buildInputs.
# • Les devDependencies (electron-builder, @electron/rebuild…) sont ignorées :
#   en plus d'être inutiles au build, @electron/rebuild gratte un dépôt git via
#   SSH (ssh://git@github.com/electron/node-gyp.git, voir package-lock) et
#   échouerait sans clé SSH. node-gyp (registry) suffit pour l'addon.
# • uiohook-napi (raccourcis globaux PTT) est une dépendance optionnelle
#   volontairement ignorée : l'app le charge en lazy dans un try/catch
#   (main.js:512). Si tu veux les raccourcis globaux, ajoute libx11/libxtst.
# • Le profil (~/.config/haven-desktop) est préservé : on ne définit PAS
#   --user-data-dir, ce paquet garde donc le même profil que ton ancienne AppImage.

{ lib, stdenv, fetchFromGitHub, makeWrapper, electron
, nodejs, python3, pkg-config, libpulseaudio, cacert
, src ? null }:

let
  # La source vient du flake (input `haven-desktop`) si fournie, sinon on
  # télécharge le tarball du tag v1.4.30 (hash à remplir ci-dessous).
  source = if src != null then src else fetchFromGitHub {
    owner = "ancsemi";
    repo = "Haven-Desktop";
    rev = "v1.4.30";
    hash = lib.fakeHash; # TODO (mode 2) : remplacer par la sortie de nix-prefetch-url
  };

  # Suit automatiquement la version : lue dans le package.json embarqué, à
  # chaque mise à jour de l'input flake `haven-desktop`.
  version = (builtins.fromJSON (builtins.readFile "${source}/package.json")).version;

  # Dépendances npm pré-téléchargées, figées par une sortie fixe (FOD). Le
  # sandbox Nix autorise le réseau pour ce type de dérivation → le build final
  # peut ensuite fonctionner sans réseau ni privilèges.
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

    # node_modules hors ligne, pré-téléchargé par la FOD `npmDeps`.
    cp -r "${npmDeps}/node_modules" node_modules

    # Compile l'addon de capture audio contre les en-têtes Node embarqués
    # (--nodedir → aucun téléchargement réseau). node-addon-api émet du N-API,
    # l'ABI est stable entre Node et Electron, le .node charge sous les deux.
    # node-gyp est celui embarqué par npm (fournit par le paquet nodejs).
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

    # Desktop integration
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