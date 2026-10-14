{
  description = "Haven Desktop — client de chat privé auto-hébergé";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    haven-latest = {
      url = "https://github.com/ancsemi/Haven-Desktop/releases/latest/download/latest-linux.yml";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, haven-latest }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      packages = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.callPackage ./package.nix {
            inherit haven-latest;
          };
        });

      overlays.default = final: prev: {
        haven-desktop = final.callPackage ./package.nix {
          inherit haven-latest;
        };
      };
    };
}
