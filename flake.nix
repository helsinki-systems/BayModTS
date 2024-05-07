{
  description = "BayModTS Flake";
  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
      };

      hdf5 = pkgs.hdf5.override {
        cppSupport = true;
        fortranSupport = false;
        mpiSupport = false;
      };
    in
    {
      packages.x86_64-linux = {
        amici = pkgs.stdenv.mkDerivation {
          name = "amici";
          src = pkgs.fetchFromGitHub {
            owner = "AMICI-dev";
            repo = "AMICI";
            rev = "v0.16.1";
            hash = "sha256-yL4p6VmtTxtsVDmfmsYmTjF9XPnCoatl14LulPDJEPw=";
          };
          nativeBuildInputs = with pkgs; [
            cmake
            pkg-config
          ];

          buildInputs = with pkgs; [
            sundials
            python3
            swig
            blas
            hdf5
            boost
          ];

          cmakeFlags = [
            "-DBUILD_TESTS=OFF"
          ];
          # checkInputs = with pkgs; [
          #   gtest
          # ];
          doCheck = false;
        };
      };
      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          gcc
          cmake
          blas
          swig
          poetry
          jupyter
        ];
      };
    };
}
