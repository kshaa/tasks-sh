{ sources ? import ./nix/sources.nix }: 
let
    pkgs = import sources.nixpkgs {};
    tasks-sh = import ./. {};
in pkgs.mkShell {
    buildInputs = [
        tasks-sh
    ];
}
