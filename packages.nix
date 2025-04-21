_: {
  perSystem =
    { pkgs, ... }:
    {
      packages = let
        dotnet-sdk = pkgs.dotnetCorePackages.sdk_9_0;
        dotnet-runtime = pkgs.dotnetCorePackages.runtime_9_0;
        saml-azure-auth-helper = pkgs.buildDotnetModule {
          inherit dotnet-sdk dotnet-runtime;

          pname = "saml-azure-auth-helper";
          version = "0.1";

          src = ./saml-azure-auth-helper;

          projectFile = "saml-azure-auth-helper.fsproj";
          nugetDeps = ./deps.json;

          executables = [ "saml-azure-auth-helper" ];
          runtimeDeps = [ pkgs.playwright-driver.browsers ];
          makeWrapperArgs = [ "--set-default PLAYWRIGHT_BROWSERS_PATH ${pkgs.playwright-driver.browsers}" ];
        };
      in {
        inherit saml-azure-auth-helper;
        default = saml-azure-auth-helper;
      };
    };
}
