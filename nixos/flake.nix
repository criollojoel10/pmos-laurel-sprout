{
  description = "NixOS for Xiaomi Mi A3 (laurel_sprout) - SM6125/Snapdragon 665";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-linux";
      pkgs = import nixpkgs {
        inherit system;
        crossSystem = nixpkgs.lib.systems.examples.aarch64-multiplatform;
      };
      # Kernel configuration for laurel_sprout
      kernelCommit = "b3f94b2b3f3e51ab880a51fc6510e1dafba654ed";
      kernelVersion = "7.1.0";
    in
    {
      nixosConfigurations = {
        laurel-console = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit kernelCommit kernelVersion;
            deviceName = "laurel_sprout";
            deviceProfile = "console";
          };
          modules = [
            ./devices/laurel-sprout
            ./configurations/console.nix
          ];
        };

        laurel-gnome = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit kernelCommit kernelVersion;
            deviceName = "laurel_sprout";
            deviceProfile = "gnome";
          };
          modules = [
            ./devices/laurel-sprout
            ./configurations/gnome.nix
          ];
        };

        laurel-kde = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit kernelCommit kernelVersion;
            deviceName = "laurel_sprout";
            deviceProfile = "kde";
          };
          modules = [
            ./devices/laurel-sprout
            ./configurations/kde.nix
          ];
        };
      };
    };
}
