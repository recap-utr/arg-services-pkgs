{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
  };
  outputs =
    inputs@{
      flake-parts,
      systems,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;
      perSystem =
        {
          pkgs,
          lib,
          self',
          ...
        }:
        {
          packages = {
            bump = pkgs.writeShellApplication {
              name = "bump-arg-services";
              text = ''
                if [ "$#" -ne 1 ]; then
                  echo "Usage: $0 VERSION" >&2
                  exit 1
                fi

                # remove v prefix
                version="''${1#v}"
                versionTag="v$version"

                # split into array
                IFS="." read -ra versionArray <<< "$version"

                if [ "''${#versionArray[@]}" -ne 3 ]; then
                  echo "Version must be in format x.y.z" >&2
                  exit 1
                fi

                minorVersion="''${versionArray[1]}"
                patchVersion="''${versionArray[2]}"

                commitPrefix="fix"

                if [ "$patchVersion" -eq 0 ]; then
                  commitPrefix="feat"
                fi
                if [ "$patchVersion" -eq 0 ] && [ "$minorVersion" -eq 0 ]; then
                  commitPrefix="feat!"
                fi

                # update deps in buf.yaml
                ${lib.getExe pkgs.sd} -- '(buf.build/recap/arg-services):v.*' "\$1:$versionTag" */buf.gen.yaml

                commitMessage="''${commitPrefix}(deps): bump arg-services to $versionTag"

                # https://stackoverflow.com/a/1885534
                read -p "Commit changes with message '$commitMessage' (y/n)? " -r shouldCommit
                if [ "$shouldCommit" = "y" ]; then
                  ${lib.getExe pkgs.mu-repo} ac "$commitMessage"

                  read -p "Push commit (y/n)? " -r shouldPush
                  if [ "$shouldPush" = "y" ]; then
                      ${lib.getExe pkgs.mu-repo} p
                  fi
                fi
              '';
            };
          };
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [ mu-repo ] ++ lib.attrValues self'.packages;
          };
        };
    };
}
