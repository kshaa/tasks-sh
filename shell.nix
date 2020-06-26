{ sources ? import ./nix/sources.nix }: 
let
    pkgs = (import sources.nixpkgs {});
    tasks-sh = builtins.trace ((import ./. {}).outPath) (import ./. {});
in pkgs.mkShell {
    buildInputs = [
        tasks-sh
    ];
}
