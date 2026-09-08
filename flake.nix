# Haven Desktop — flake Nix.
#
# ── Installation directe sur NixOS depuis ce flake ──────────────────────────
# Localement (sans git) :
#   nix profile install "path:/persist/FileFlow/haven-desktop-nix"
#
# Ou dans ta config NixOS, si le dossier est publié sur GitHub (ou déclaré
# comme input local) :
#   inputs.haven-desktop.url = "github:<ton-user>/haven-desktop-nix";
#   ...
#   environment.systemPackages = [
#     inputs.haven-desktop.packages.${pkgs.system}.default
#   ];
#
# ── Suivre les versions de Haven-Desktop ───────────────────────────────────
# L'input `haven-desktop` suit la branche par défaut du projet ; la *version*
# du paquet est lue dans le package.json embarqué (voir package.nix). Pour
# ramener la dernière version publiée :
#   nix flake update haven-desktop
#
# ── Build ──────────────────────────────────────────────────────────────────
# `npm install` a besoin du réseau → hors sandbox :
#   nix build .#default --option sandbox false
#   sudo nixos-rebuild switch --option sandbox false

{
  description = "Haven Desktop — client de chat privé auto-hébergé";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    haven-desktop = {
      url = "github:ancsemi/Haven-Desktop";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, haven-desktop }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      packages = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.callPackage ./package.nix {
            src = haven-desktop;
          };
        });

      overlays.default = final: prev: {
        haven-desktop = final.callPackage ./package.nix {
          src = haven-desktop;
        };
      };
    };
}