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