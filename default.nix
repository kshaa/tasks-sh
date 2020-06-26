{ sources ? import ./nix/sources.nix }: 
let
    pkgs = (import sources.nixpkgs {});
    gitignore = (import sources.gitignore {});
    gitignoreSource = gitignore.gitignoreSource;
in with pkgs; stdenv.mkDerivation {
    pname = "tasks-sh";
    version = "1.0.0";
    nativeBuildInputs = [ makeWrapper ];
    src = gitignoreSource ./.;
    installPhase = ''
        install -m755 -D tasks.sh "$out/bin/tasks.sh"
        wrapProgram "$out/bin/tasks.sh" \
            --prefix PATH : "${stdenv.lib.makeBinPath [ yq jq ]}"
    '';
}