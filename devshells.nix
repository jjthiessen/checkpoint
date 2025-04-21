{ self, ... }: {
  perSystem =
    { pkgs, system, ... }: let
      packages = self.packages.${system};
      helper = packages.saml-azure-auth-helper;

      fromJSONFile = f: f |> builtins.readFile |> builtins.fromJSON;
      toJSONFile = f: x: x |> builtins.toJSON |> builtins.toFile f;
      concatJSONFiles = out: fs: fs |> builtins.concatMap fromJSONFile |> toJSONFile out;

      helperDeps = pkgs.dotnetCorePackages.mkNugetDeps {
        name = helper.pname;
        sourceFile = [ ./deps.manual.json ./deps.json ] |> concatJSONFiles "deps.merged.json";
      };
    in {
      devShells = {
        default = pkgs.mkShell {
          NUGET_PACKAGES = "${helperDeps}/share/nuget/packages";
          PLAYWRIGHT_BROWSERS_PATH = pkgs.playwright-driver.browsers;

          buildInputs = helper.buildInputs
            ++ helper.nativeBuildInputs
            ++ helper.propagatedBuildInputs;

          packages = [
            pkgs.fsautocomplete
            pkgs.snx-rs

            (pkgs.writeShellScriptBin "xdg-open" ''
              set -euo pipefail
              REPO_ROOT="$(git rev-parse --show-toplevel)"
              ( eval $GET_CREDS ) | dotnet run --project "$REPO_ROOT/saml-azure-auth-helper" -- "$@"
            '')
          ];
        };
      };
    };
}
