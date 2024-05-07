{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      poetry2nix,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) python3;

        src = pkgs.nix-gitignore.gitignoreSource [ ] ./.;
        version = "0.0.1";

        p2n = poetry2nix.lib.mkPoetry2Nix { inherit pkgs; };
        overrides = p2n.overrides.withDefaults (
          self: super: {
            fides = super.fides.overridePythonAttrs (old: {
              buildInputs = (old.buildInputs or [ ]) ++ [ super.setuptools ];
            });

            pydotplus = super.pydotplus.overridePythonAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ super.setuptools ];
            });

            amici = super.amici.overridePythonAttrs (old: {
              patches = old.patches or [ ] ++ [
                (pkgs.fetchpatch {
                  url = "https://github.com/AMICI-dev/AMICI/commit/ecd6bbbe281f162711e55a1d171b1a945c191bf8.patch";
                  hash = "sha256-4XFlp7fqDrdwgMjZWbQT7fMmLYPD67cVyNkP2tDmCH8=";
                })
              ];
              prePatch = ''
                pushd amici
              '';
              postPatch = ''
                popd
              '';
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
                super.pkgconfig
                pkgs.boost
                pkgs.pkg-config
                pkgs.blas.dev
                pkgs.hdf5
                pkgs.swig
              ];

              HDF5_BASE = "${pkgs.symlinkJoin {
                name = "hdf5-combined";
                paths = [
                  pkgs.hdf5-cpp.dev
                  pkgs.hdf5-cpp.out
                ];
              }}";
              BLAS_LIBS = " -L${pkgs.blas.out}/lib -lcblas ";
              BLAS_CFLAGS = " -I${pkgs.blas.dev}/include ";
              SWIG = "${pkgs.swig}/bin/swig";
            });
          }
        );

        libroadrunner-deps = pkgs.stdenv.mkDerivation rec {
          pname = "libroadrunner-deps";
          version = "2.1";

          src = pkgs.fetchFromGitHub {
            owner = "sys-bio";
            repo = pname;
            rev = "v${version}";
            fetchSubmodules = true;
            hash = "sha256-MF1s7UmZ898OgFZtHW/GgIqh7UG1+dxY7JjstzIzu1M=";
          };

          cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];

          hardeningDisable = [ "format" ];

          nativeBuildInputs = [ pkgs.cmake ];
          buildInputs = [
            pkgs.boost
            pkgs.eigen
            pkgs.libxml2
            pkgs.mpi
            python3
            python3.pkgs.numpy
          ];
        };

        libroadrunner =
          let
            roadrunner = pkgs.stdenv.mkDerivation rec {
              version = "2.6.0";
              pname = "roadrunner";

              src = pkgs.fetchFromGitHub {
                owner = "sys-bio";
                repo = pname;
                rev = "v${version}";
                hash = "sha256-2khOg0/6v4uOamM9fO1N6Y9gBEXPPgH5gBI2A9gA9gs=";
              };

              cmakeFlags = [
                "-DCMAKE_BUILD_TYPE=Release"
                "-DBUILD_RR_PLUGINS=ON"
                "-DRR_DEPENDENCIES_INSTALL_PREFIX=${libroadrunner-deps}"
                "-DLLVM_INSTALL_PREFIX=${pkgs.llvm_13}"
                "-DBUILD_TESTS=ON"
                "-DBUILD_PYTHON=ON"
                "-DSWIG_EXECUTABLE=${pkgs.swig4}/bin/swig"
                "-DPython_ROOT_DIR=${python3}"
                "-DPython_EXECUTABLE=${python3}/bin/python"
                "-DPython_INCLUDE_DIRS=${python3}/include"
                "-DPython_LIBRARIES=${python3}/lib"
                "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
              ];

              nativeBuildInputs = [
                pkgs.cmake
                pkgs.pkg-config
                pkgs.expat
              ];
              buildInputs = [
                pkgs.boost
                pkgs.eigen
                pkgs.libxml2Python
                pkgs.libxml2
                pkgs.mpi
                python3
                python3.pkgs.numpy
                python3.pkgs.matplotlib
                libroadrunner-deps
                pkgs.llvm_13
                pkgs.swig4
              ];
            };

            roadrunner-python = python3.pkgs.buildPythonPackage {
              pname = "roadrunner-python";
              version = "2.6.0";
              src = roadrunner;
              pythonImportsCheck = [ "roadrunner" ];

              buildInputs = with python3.pkgs; [
                numpy
                # matplotlib
              ];
            };
          in
          roadrunner-python // { passthru.python = roadrunner-python; };
        # in roadrunner // { passthru.python = roadrunner-python; };

        py2cytoscape = python3.pkgs.buildPythonPackage rec {
          pname = "py2cytoscape";
          version = "0.7.1";
          src = pkgs.fetchFromGitHub {
            owner = "cytoscape";
            repo = pname;
            rev = version;
            hash = "sha256-lynVkwYNGNnCB+6gZmyEmvW5l0HHwsjN3dj69BQaq7U=";
          };

          doCheck = false;
          nativeBuildInputs = with python3.pkgs; [ pip ];
          propagatedBuildInputs = with python3.pkgs; [
            networkx
            igraph
          ];
        };

        sbmlutils = python3.pkgs.buildPythonPackage rec {
          pname = "sbmlutils";
          version = "0.8.7";

          src = pkgs.fetchFromGitHub {
            owner = "matthiaskoenig";
            repo = "sbmlutils";
            rev = version;
            hash = "sha256-fNLDgEW2uppKB8fv1zDqn+ilYPZTuvSl/izeiDOLC/c=";
          };

          doCheck = false;
          nativeBuildInputs = with python3.pkgs; [
            pip
            pytest-runner
          ];
          propagatedBuildInputs = with python3.pkgs; [
            py2cytoscape
            libroadrunner
            rich
            (python3.pkgs.buildPythonPackage {
              pname = "antimony";
              version = "2.14.0";
              format = "wheel";
              src = pkgs.fetchurl {
                url = "https://files.pythonhosted.org/packages/2f/57/674a39b3569ea0e5a1fa3d80ec0c8e6c18cf60594623649fc904a9e13779/antimony-2.14.0-py3-none-manylinux2014_x86_64.whl";
                hash = "sha256-BIPktNmYfi4cNgQiuUAifimL3doRBP/Yy0u0+L/R6ZQ=";
              };
            })
            (python3.pkgs.buildPythonPackage rec {
              pname = "pymetadata";
              version = "0.4.1";
              src = pkgs.fetchFromGitHub {
                owner = "matthiaskoenig";
                repo = pname;
                rev = version;
                hash = "sha256-AQPdOqBGP888UE6v8Fb8PnzRFvQciDNJUGh2YF99gQo=";
              };
              patches = [
                (pkgs.fetchpatch {
                  url = "https://github.com/matthiaskoenig/pymetadata/commit/59a30e4feb6207ce86b2845e40ee54a378e25687.patch";
                  hash = "sha256-b0cSzngSu8RBWsfIgI4d+QWwjRinhLNSjYbt1SoQuvM=";
                })
              ];
              # Also, maybe the poetry thingy works now: https://github.com/matthiaskoenig/pymetadata/commit/b8f7a0c0b9f5085218cc02daa2e6f8179b9d18a7
              doCheck = false;
              propagatedBuildInputs = with python3.pkgs; [
                xmltodict
                # pydantic
                # (pkgs.python3.pkgs.pydantic.override { inherit (python3.pkgs) buildPythonPackage; })
                (python3.pkgs.callPackage "${nixpkgs}/pkgs/development/python-modules/pydantic" {
                  hatchling = python3.pkgs.callPackage "${nixpkgs}/pkgs/development/python-modules/hatchling" { };
                })
                # (python3.pkgs.callPackage "${nixpkgs}/pkgs/development/python-modules/pydantic" { inherit (python3.pkgs) hatchling; })
                # (pydantic.overrideAttrs (old: rec {
                #   version = "2.6.4";
                #   nativeBuildInputs = old.nativeBuildInputs ++ [
                #     pkgs.pdm
                #     python3.pkgs.mkdocs-material
                #     python3.pkgs.mkdocs-material-extensions
                #   ];
                #   src = pkgs.fetchFromGitHub {
                #     owner = "pydantic";
                #     repo = old.pname;
                #     rev = "v${version}";
                #     hash = "sha256-z4m1Rsv5H3mI94o0LLd2xSwhPK35WgMYfuUBNPrtAMk=";
                #   };
                # }))
              ];
            })
            pint
          ];
        };

        tellurium = python3.pkgs.buildPythonPackage rec {
          pname = "tellurium";
          version = "2.2.10";
          src = pkgs.fetchFromGitHub {
            owner = "sys-bio";
            repo = pname;
            rev = version;
            hash = "sha256-xtZAagTypAbwTLDv3saaAu7DoJLZ7lWtkUqmqlzhXsE=";
          };
          doCheck = false;
          nativeBuildInputs = with python3.pkgs; [ pip ];
        };

        baymod =
          (p2n.mkPoetryApplication {
            pname = "BayModTS";
            inherit version src overrides;
            python = python3;
            preferWheels = true;
            projectDir = src;
            propagatedBuildInputs = [ sbmlutils ];
          }).dependencyEnv;
        poetry_env = p2n.mkPoetryEnv {
          preferWheels = true;
          projectDir = src;
          python = python3;
          inherit overrides;
        };
      in
      {
        packages = {
          default = baymod;
          inherit sbmlutils libroadrunner-deps libroadrunner;
        };
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            python3.pkgs.flake8
            python3.pkgs.black
            python3.pkgs.isort
            poetry
            poetry_env
            # (jupyter.override { inherit python3; })
            jupyter
            tellurium
            sbmlutils
          ];
        };
      }
    );
}
