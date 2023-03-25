{
  description = "Minimal package for Marlowe validator";
  nixConfig = {
    extra-substituters = [
      "https://cache.zw3rk.com"
      "https://cache.iog.io"
      "https://hydra.iohk.io"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "loony-tools:pr9m4BkM/5/eSTZlkQyRt57Jz7OMBxNSUiMC4FkcNfk="
    ];
    allow-import-from-derivation = true;
  };
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    haskell-nix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.follows = "haskell-nix/nixpkgs-2205";
    CHaP = {
      url = "github:input-output-hk/cardano-haskell-packages?ref=repo";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, flake-utils, haskell-nix, CHaP }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        overlays = [ haskell-nix.overlay
          (final: prev: {
            marlowe-cardano-minimal =
              final.haskell-nix.project' {
                inputMap = {
                  "https://input-output-hk.github.io/cardano-haskell-packages" = CHaP;
                };
                src = ./.;
                compiler-nix-name = "ghc925";
                shell.tools = {
                  cabal = {};
                # haskell-language-server = {};
                # hie-bios = {};
                };
              };
          })
        ];
        pkgs = import nixpkgs { inherit system overlays; inherit (haskell-nix) config; };
        flake = pkgs.marlowe-cardano-minimal.flake {
        };
      in
        flake // {
          defaultPackage = flake.packages."marlowe-cardano-minimal:lib:marlowe-cardano-minimal";
        }
    );
}
