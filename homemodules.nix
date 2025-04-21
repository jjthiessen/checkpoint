{ self, ... }: {
  flake = {
    homeModules = {
      snxAzureAuthHelper = { config, lib, pkgs, ... }: let
        cfg = config.ca.tangential.snxAzureAuthHelper;
        system = pkgs.stdenv.hostPlatform.system;
      in {
        options.ca.tangential.snxAzureAuthHelper = {
          enable = lib.mkEnableOption "Install a wrapped version of snx-rs for scripted Azure SAML authentication";

          credentialScript = lib.mkOption {
            type = lib.types.path;
            description = "Script that produces email, password, and TOTP code (each on their own line)";
          };

          providerURLRegex = lib.mkOption {
            type = lib.types.str;
            description = "A regular expression to filter URL opening requests";
          };

          snx-rs = lib.mkOption {
            type = lib.types.package;
            default = pkgs.snx-rs;
            description = "snx-rs package to use/wrap";
          };

          wrapped = lib.mkOption {
            type = lib.types.package;
            internal = true;
            readOnly = true;
          };
        };

        config = lib.mkIf cfg.enable (let
          fake-xdg-open = pkgs.writeShellScriptBin "xdg-open" ''
            set -eu
            if echo "$@" | grep -Eq '${cfg.providerURLRegex}'; then
              creds="$(${cfg.credentialScript})"
              if [ "$(echo "$creds" | tr -s $'\n' | wc -l)" -eq 3 ]; then
                echo "$creds" | tr -s $'\n' | ${self.packages.${system}.saml-azure-auth-helper}/bin/saml-azure-auth-helper "$@"
              else
                echo 'The credentials helper failed to yield exactly three non-empty lines' >&2
                exit 1
              fi
            else
              echo 'Invalid SAML service provider URL—shunting request to real xdg-open...' >&2
              ${pkgs.xdg-utils}/bin/xdg-open "$@"
            fi
          '';
          snx-rs-wrapped = pkgs.symlinkJoin {
            name = "snx-rs-wrapped";
            paths = [ cfg.snx-rs ];
            buildInputs = [ pkgs.makeWrapper ];
            runtimeInputs = [ fake-xdg-open ];
            postBuild = ''
              wrapProgram $out/bin/snxctl --prefix PATH : "${fake-xdg-open}/bin"
              wrapProgram $out/bin/snx-rs-gui --prefix PATH : "${fake-xdg-open}/bin"
            '';
          };
        in {
          ca.tangential.snxAzureAuthHelper.wrapped = snx-rs-wrapped;

          home.packages = [
            snx-rs-wrapped
          ];
        });
      };
    };
  };
}
