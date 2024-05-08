{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        py = pkgs.python3.override {
          packageOverrides = _selfPy: superPy: {
            pydantic-core = superPy.buildPythonPackage rec {
              pname = "pydantic-core";
              version = "2.16.3";
              pyproject = true;

              src = pkgs.fetchFromGitHub {
                owner = "pydantic";
                repo = "pydantic-core";
                rev = "refs/tags/v${version}";
                hash = "sha256-RXytujvx/23Z24TWpvnHdjJ4/dXqjs5uiavUmukaD9A=";
              };

              # patches = [
              #   ./01-remove-benchmark-flags.patch
              # ];

              cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
                inherit src;
                name = "${pname}-${version}";
                hash = "sha256-wj9u6s/3E3EWfQydkLrwHbJBvm8DwcGCoQQpSw1+q7U=";
              };

              nativeBuildInputs = [
                pkgs.rustPackages_1_76.cargo
                pkgs.rustPackages_1_76.rustPlatform.cargoSetupHook
                pkgs.rustPackages_1_76.rustc
                (pkgs.rustPackages_1_76.rustPlatform.maturinBuildHook.overrideAttrs (_: {
                  propagatedBuildInputs = [
                    pkgs.maturin
                    pkgs.rustPackages_1_76.cargo
                    pkgs.rustPackages_1_76.rustc
                  ];
                }))
                superPy.typing-extensions
              ];

              buildInputs = [ pkgs.libiconv ];

              propagatedBuildInputs = [ superPy.typing-extensions ];

              pythonImportsCheck = [ "pydantic_core" ];

              # escape infinite recursion with pydantic via dirty-equals
              doCheck = false;
            };

            pydantic-settings = superPy.buildPythonPackage rec {
              pname = "pydantic-settings";
              version = "2.2.1";
              pyproject = true;

              src = pkgs.fetchFromGitHub {
                owner = "pydantic";
                repo = "pydantic-settings";
                rev = "refs/tags/v${version}";
                hash = "sha256-4o8LlIFVizoxb484lVT67e24jhtUl49otr1lX/2zZ4M=";
              };

              nativeBuildInputs = [ superPy.hatchling ];

              propagatedBuildInputs = [
                py.pkgs.pydantic
                superPy.python-dotenv
              ];

              pythonImportsCheck = [ "pydantic_settings" ];

              # ruff is a dependency of pytest-examples which is required to run the tests.
              # We do not want all of the downstream packages that depend on pydantic-settings to also depend on ruff.
              doCheck = false;
            };

            pydantic-extra-types = superPy.buildPythonPackage rec {
              pname = "pydantic-extra-types";
              version = "2.6.0";
              pyproject = true;

              src = pkgs.fetchFromGitHub {
                owner = "pydantic";
                repo = "pydantic-extra-types";
                rev = "refs/tags/v${version}";
                hash = "sha256-XLVhoZ3+TfVYEuk/5fORaGpCBaB5NcuskWhHgt+llS0=";
              };

              nativeBuildInputs = [ superPy.hatchling ];

              propagatedBuildInputs = [ py.pkgs.pydantic ];

              pythonImportsCheck = [ "pydantic_extra_types" ];
              doCheck = false;
            };

            pydantic = superPy.buildPythonPackage rec {
              pname = "pydantic";
              version = "2.6.3";
              pyproject = true;

              src = pkgs.fetchFromGitHub {
                owner = "pydantic";
                repo = "pydantic";
                rev = "refs/tags/v${version}";
                hash = "sha256-neTdG/IcXopCmevzFY5/XDlhPHmOb6dhyAnzaobmeG8=";
              };

              patches = [
                (pkgs.fetchpatch2 {
                  # https://github.com/pydantic/pydantic/pull/8678
                  name = "fix-pytest8-compatibility.patch";
                  url = "https://github.com/pydantic/pydantic/commit/825a6920e177a3b65836c13c7f37d82b810ce482.patch";
                  hash = "sha256-Dap5DtDzHw0jS/QUo5CRI9sLDJ719GRyC4ZNDWEdzus=";
                })
              ];

              buildInputs = [ pkgs.libxcrypt ];

              nativeBuildInputs = [
                superPy.hatch-fancy-pypi-readme
                superPy.hatchling
              ];

              propagatedBuildInputs = [
                superPy.annotated-types
                py.pkgs.pydantic-core
                superPy.typing-extensions
              ];

              pythonImportsCheck = [ "pydantic" ];
            };
          };
        };

        h5py = py.pkgs.h5py.overridePythonAttrs (oA: rec {
          version = "3.8.0";
          src = py.pkgs.fetchPypi {
            inherit (oA) pname;
            inherit version;
            hash = "sha256-b+rYLwxAAM841T+cAweA2Bv6AiAhiu4TuQt3Ack32V8=";
          };
        });

        libsbml = pkgs.stdenv.mkDerivation rec {
          pname = "libsbml";
          version = "5.20.2";

          src = pkgs.fetchFromGitHub {
            owner = "sbmlteam";
            repo = "libsbml";
            rev = "v${version}";
            hash = "sha256-8JT2r0zuf61VewtZaOAccaOUmDlQPnllA0fXE9rT5X8=";
          };

          hardeningDisable = [ "format" ];
          nativeBuildInputs = [
            pkgs.cmake
            pkgs.pkg-config
            py.pkgs.pythonImportsCheckHook
          ];
          buildInputs = [
            pkgs.swig
            pkgs.expat
            pkgs.bzip2
            pkgs.zlib
            py
          ];

          cmakeFlags = [
            "-DWITH_PYTHON=ON"
            "-DWITH_EXPAT=ON"
            "-DWITH_STABLE_PACKAGES=ON"
          ];

          postInstall = ''
            mv $out/${py.sitePackages}/libsbml/libsbml.py $out/${py.sitePackages}/libsbml/__init__.py
          '';

          pythonImportsCheck = [ "libsbml" ];
        };
        python-libsbml = py.pkgs.toPythonModule libsbml;

        amici = py.pkgs.buildPythonPackage rec {
          pname = "amici";
          version = "0.16.0";

          src = py.pkgs.fetchPypi {
            inherit pname version;
            hash = "sha256-Gi1mM+w0JB2Ni0ltGNQxhILP/hJend88psrF020jXzg=";
          };

          env = {
            BLAS_CFLAGS = "-I${pkgs.blas.dev}/include";
            BLAS_LIBS = "-L${pkgs.blas}/lib -lcblas";
          };

          nativeBuildInputs = [
            # py.pkgs.pip
            pkgs.swig
          ];

          propagatedBuildInputs = [
            py.pkgs.sympy
            py.pkgs.numpy
            python-libsbml
            h5py
            py.pkgs.pandas
            py.pkgs.pkgconfig
            py.pkgs.wurlitzer
            py.pkgs.toposort
            py.pkgs.mpmath

            # optional
            petab
            # pysb
          ];

          pythonImportsCheck = [ "amici" ];
          doCheck = false;
        };

        fides = py.pkgs.buildPythonPackage rec {
          pname = "fides";
          version = "0.7.5";

          src = py.pkgs.fetchPypi {
            inherit pname version;
            hash = "sha256-pRBVz0VdqAr9amfa8PAIhSfbeidvYHexy/fD8IlZ2c0=";
          };

          pythonImportsCheck = [ "fides" ];

          propagatedBuildInputs = [
            py.pkgs.scipy
            py.pkgs.numpy
            h5py
          ];

          doCheck = false;
        };

        petab = py.pkgs.buildPythonPackage rec {
          pname = "petab";
          version = "0.1.30";

          src = py.pkgs.fetchPypi {
            inherit pname version;
            hash = "sha256-Tc74582cvUhbVnQAHU2PSORmkqZmJM0YvBbVI25TwFg=";
          };

          pythonImportsCheck = [ "petab" ];

          propagatedBuildInputs = [
            py.pkgs.numpy
            py.pkgs.pandas
            py.pkgs.matplotlib
            python-libsbml
            py.pkgs.sympy
            py.pkgs.colorama
            py.pkgs.seaborn
            py.pkgs.pyyaml
            py.pkgs.jsonschema
          ];

          doCheck = false;
        };

        pypesto = py.pkgs.buildPythonPackage rec {
          pname = "pypesto";
          version = "0.2.15";

          src = py.pkgs.fetchPypi {
            inherit pname version;
            hash = "sha256-i3jDaul1xMXABBnatanN6SzqRwQK/BoD7kNeuZy+76M=";
          };

          pythonImportsCheck = [ "pypesto" ];

          propagatedBuildInputs = [
            py.pkgs.numpy
            py.pkgs.scipy
            py.pkgs.pandas
            py.pkgs.cloudpickle
            py.pkgs.matplotlib
            py.pkgs.more-itertools
            py.pkgs.seaborn
            h5py
            py.pkgs.tqdm
            py.pkgs.tabulate
          ];

          doCheck = false;
        };

        versioneer-518 = py.pkgs.buildPythonPackage rec {
          pname = "versioneer-518";
          version = "0.19";

          src = py.pkgs.fetchPypi {
            inherit pname version;
            hash = "sha256-oodgiZdBX0VAGEnRInpCu0G4Cm5KfaV3Zmb4XOb67EE=";
          };

          pythonImportsCheck = [ "versioneer" ];

          nativeBuildInputs = [
            py.pkgs.setuptools
          ] ++ pkgs.lib.optionals (py.pkgs.pythonOlder "3.11") [ py.pkgs.tomli ];

          doCheck = false;
        };

        depinfo = py.pkgs.buildPythonPackage rec {
          pname = "depinfo";
          version = "2.2.0";
          format = "pyproject";

          src = py.pkgs.fetchPypi {
            inherit pname version;
            hash = "sha256-4Jcb4RUZqCOxJsh14XrTrYrapqhnNzlbnbzvPKDneww=";
          };

          pythonImportsCheck = [ "depinfo" ];

          propagatedBuildInputs = [
            py.pkgs.setuptools
            versioneer-518
          ];
        };

        fastobo = py.pkgs.buildPythonPackage rec {
          pname = "fastobo";
          version = "0.12.3";
          format = "pyproject";

          src = pkgs.fetchFromGitHub {
            owner = "fastobo";
            repo = "fastobo-py";
            rev = "v${version}";
            hash = "sha256-UO3hCZA0FoLmrjfS+vp8xe1b8IzxPkfIhwFnG1TSQ9Q=";
          };

          cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
            inherit src;
            hash = "sha256-rzl8qkr4TY1z9n7cIA/NX0nCb/54D8elCGah7Llg2EE=";
          };

          pythonImportsCheck = [ "fastobo" ];

          nativeBuildInputs = [
            py.pkgs.setuptools
            pkgs.rustPlatform.cargoSetupHook
            py.pkgs.setuptools-rust
            pkgs.cargo
            pkgs.rustc
          ];
        };

        pronto = py.pkgs.buildPythonPackage rec {
          pname = "pronto";
          version = "2.5.7";

          src = py.pkgs.fetchPypi {
            inherit pname version;
            hash = "sha256-AUpbAgZHgdbt18pbT2OxM0Ldm1MiJI9aR0D0iphGRik=";
          };

          pythonImportsCheck = [ "pronto" ];

          propagatedBuildInputs = [
            py.pkgs.chardet
            fastobo
            py.pkgs.networkx
            py.pkgs.python-dateutil
          ];

          doCheck = false;
        };

        pymetadata = py.pkgs.buildPythonPackage rec {
          pname = "pymetadata";
          version = "0.4.2";

          src = py.pkgs.fetchPypi {
            inherit pname version;
            hash = "sha256-45w0+d5xdVk1xAIklEZosO6CZDEiHuem7A489Grzl/A=";
          };

          patches = [ ./01-fixpymetadata.patch ];

          pythonImportsCheck = [ "pymetadata" ];

          propagatedBuildInputs = [
            depinfo
            py.pkgs.lxml
            py.pkgs.rich
            py.pkgs.requests
            py.pkgs.zeep
            pronto
            fastobo
            py.pkgs.jinja2
            py.pkgs.xmltodict
            py.pkgs.pydantic
          ];

          doCheck = false;
        };

        antimony = py.pkgs.buildPythonPackage {
          pname = "antimony";
          version = "2.14.0";
          format = "wheel";

          src = pkgs.fetchurl {
            url = "https://files.pythonhosted.org/packages/2f/57/674a39b3569ea0e5a1fa3d80ec0c8e6c18cf60594623649fc904a9e13779/antimony-2.14.0-py3-none-manylinux2014_x86_64.whl";
            hash = "sha256-BIPktNmYfi4cNgQiuUAifimL3doRBP/Yy0u0+L/R6ZQ=";
          };

          pythonImportsCheck = [ "antimony" ];

          nativeBuildInputs = [ pkgs.autoPatchelfHook ];

          buildInputs = [
            pkgs.expat
            pkgs.libz
            pkgs.stdenv.cc
          ];

          doCheck = false;
        };

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

          hardeningDisable = [ "format" ];

          nativeBuildInputs = [ pkgs.cmake ];
          buildInputs = [
            pkgs.boost
            pkgs.eigen
            pkgs.libxml2
            pkgs.mpi
            py
            py.pkgs.numpy
          ];

          enableParallelBuilding = true;
        };

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
            "-DPython_ROOT_DIR=${py}"
            "-DPython_EXECUTABLE=${py}/bin/python"
            "-DPython_INCLUDE_DIRS=${py}/include"
            "-DPython_LIBRARIES=${py}/lib"
            "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
          ];

          hardeningDisable = [ "format" ];
          doCheck = false;

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
            py
            py.pkgs.numpy
            py.pkgs.matplotlib
            libroadrunner-deps
            pkgs.llvm_13
            pkgs.swig4
          ];

          enableParallelBuilding = true;
        };

        roadrunner-python = py.pkgs.buildPythonPackage {
          pname = "roadrunner-python";
          version = "2.6.0";
          src = roadrunner;
          pythonImportsCheck = [ "roadrunner" ];

          buildInputs = [ py.pkgs.numpy ];
        };

        libroadrunner = roadrunner-python // {
          passthru.python = roadrunner-python;
        };

        py2cytoscape = py.pkgs.buildPythonPackage rec {
          pname = "py2cytoscape";
          version = "0.7.1";
          src = pkgs.fetchFromGitHub {
            owner = "cytoscape";
            repo = pname;
            rev = version;
            hash = "sha256-lynVkwYNGNnCB+6gZmyEmvW5l0HHwsjN3dj69BQaq7U=";
          };

          doCheck = false;
          propagatedBuildInputs = [
            py.pkgs.networkx
            py.pkgs.igraph
          ];

          pythonImportsCheck = [ "py2cytoscape" ];
        };

        sbmlutils = py.pkgs.buildPythonPackage rec {
          pname = "sbmlutils";
          version = "0.8.7";

          src = py.pkgs.fetchPypi {
            inherit pname version;
            hash = "sha256-d+8NGwq3glIwHxearLlN5Op8uuEYZ+pxAalTYx8+DPg=";
          };

          pythonImportsCheck = [ "sbmlutils" ];

          nativeBuildInputs = [
            py.pkgs.pip
            py.pkgs.pytest-runner
          ];
          propagatedBuildInputs = [
            pymetadata
            depinfo
            py.pkgs.rich
            py.pkgs.lxml
            py.pkgs.requests
            py.pkgs.jinja2
            py.pkgs.xmltodict
            py.pkgs.pydantic

            py.pkgs.numpy
            python-libsbml
            antimony

            py.pkgs.scipy
            py.pkgs.pandas
            py.pkgs.pint
            py.pkgs.tabulate
            py.pkgs.beautifulsoup4
            py.pkgs.markdown-it-py
            py.pkgs.openpyxl
            py.pkgs.xmlschema

            py.pkgs.matplotlib

            (py.pkgs.fastapi.overridePythonAttrs (oA: {
              propagatedBuildInputs = oA.propagatedBuildInputs ++ [
                py.pkgs.pydantic-settings
                py.pkgs.pydantic-extra-types
              ];
              doCheck = false;
            }))
            py.pkgs.uvicorn
            py.pkgs.python-multipart
            py2cytoscape

            libroadrunner
          ];

          doCheck = false;
        };

        zipper = pkgs.stdenv.mkDerivation {
          pname = "zipper";
          version = "unstable-2024-05-22";

          src = pkgs.fetchFromGitHub {
            owner = "fbergmann";
            repo = "zipper";
            rev = "c56a27fa282b7f353b498d60eee636793342b8bb";
            hash = "sha256-JFTJepAmN1stk1+5ft7KrKQrYpmsJ63nqB1Xi+yFDLA=";
            fetchSubmodules = true;
          };

          nativeBuildInputs = [
            pkgs.cmake
            pkgs.pkg-config
          ];
          buildInputs = [ pkgs.zlib ];
        };

        libnuml = pkgs.stdenv.mkDerivation rec {
          pname = "libnuml";
          version = "1.1.6";

          src =
            pkgs.fetchFromGitHub {
              owner = "numl";
              repo = "numl";
              rev = "v${version}";
              hash = "sha256-Y22jfLdensuEiyiecw4nbDzrx64Y8iZ7k/tWDI4Hy2I=";
            }
            + "/libnuml";

          preConfigure = ''
            # we need to drop that directory otherwise dependencies are not found correctly
            rm -rf submodules
          '';

          nativeBuildInputs = [
            pkgs.cmake
            pkgs.pkg-config
            py.pkgs.pythonImportsCheckHook
          ];

          buildInputs = [
            pkgs.swig
            libsbml
            pkgs.expat
            pkgs.bzip2
            pkgs.zlib
            py
          ];

          cmakeFlags = [
            "-DWITH_PYTHON=ON"
            "-DEXTRA_LIBS=expat;bz2;z"
          ];

          postInstall = ''
            mv $out/${py.sitePackages}/libnuml/libnuml.py $out/${py.sitePackages}/libnuml/__init__.py
          '';

          pythonImportsCheck = [ "libnuml" ];
        };
        python-libnuml = py.pkgs.toPythonModule libnuml;

        libsedml = pkgs.stdenv.mkDerivation rec {
          pname = "libsedml";
          version = "2.0.32";

          src = pkgs.fetchFromGitHub {
            owner = "fbergmann";
            repo = "libsedml";
            rev = "v${version}";
            hash = "sha256-ZMgZZB4/YQfN0/fZwBFgAKSyxIxrniEMtSwZEO56rVM=";
          };

          preConfigure = ''
            # we need to drop that directory otherwise dependencies are not found correctly
            rm -rf submodules
          '';

          nativeBuildInputs = [
            pkgs.cmake
            pkgs.pkg-config
            py.pkgs.pythonImportsCheckHook
          ];

          buildInputs = [
            pkgs.swig
            libsbml
            libnuml
            pkgs.expat
            pkgs.bzip2
            pkgs.zlib
            py
          ];

          cmakeFlags = [
            "-DWITH_PYTHON=ON"
            "-DEXTRA_LIBS=expat;bz2;z"
          ];

          postInstall = ''
            mv $out/${py.sitePackages}/libsedml/libsedml.py $out/${py.sitePackages}/libsedml/__init__.py
          '';

          pythonImportsCheck = [ "libsedml" ];
        };
        python-libsedml = py.pkgs.toPythonModule libsedml;

        libcombine = pkgs.stdenv.mkDerivation rec {
          pname = "libcombine";
          version = "0.2.20";

          src = pkgs.fetchFromGitHub {
            owner = "sbmlteam";
            repo = "libcombine";
            rev = "v${version}";
            hash = "sha256-3ZxJM+8I2zVQNTPCj3yl8sJuuM6xzrpCtyv//NsqsMk=";
          };

          preConfigure = ''
            # we need to drop that directory otherwise dependencies are not found correctly
            rm -rf submodules
          '';

          nativeBuildInputs = [
            pkgs.cmake
            pkgs.pkg-config
            py.pkgs.pythonImportsCheckHook
          ];

          buildInputs = [
            pkgs.swig
            libsbml
            pkgs.expat
            pkgs.bzip2
            pkgs.zlib
            zipper
            py
          ];

          env = {
            ZIPPER_DIR = "${zipper}";
          };

          cmakeFlags = [
            "-DWITH_PYTHON=ON"
            "-DEXTRA_LIBS=expat;bz2;z"
          ];

          postInstall = ''
            mv $out/${py.sitePackages}/libcombine/libcombine.py $out/${py.sitePackages}/libcombine/__init__.py
          '';

          pythonImportsCheck = [ "libcombine" ];
        };
        python-libcombine = py.pkgs.toPythonModule libcombine;

        tellurium = py.pkgs.buildPythonPackage {
          pname = "tellurium";
          version = "2.2.10";
          format = "wheel";

          src = pkgs.fetchurl {
            url = "https://files.pythonhosted.org/packages/71/11/91d301a77e9afe3a81194f239e4a1a96bcc84ce9774b598627bec5ff5267/tellurium-2.2.10-py3-none-any.whl";
            hash = "sha256-B42+W+7vScyMqp9ibLnI5Wh1Ls+v8zcKzTK+Ej1uJK4=";
          };

          pythonImportsCheck = [ "tellurium" ];

          propagatedBuildInputs = [
            py.pkgs.numpy
            py.pkgs.scipy
            py.pkgs.matplotlib
            py.pkgs.pandas

            libroadrunner
            antimony

            python-libsbml
            python-libnuml
            python-libsedml
            python-libcombine

            py.pkgs.appdirs
            py.pkgs.jinja2
            py.pkgs.plotly
            py.pkgs.requests

            py.pkgs.jupyter-client
            py.pkgs.jupyter-core
            py.pkgs.ipython
            py.pkgs.ipykernel
          ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            py.pkgs.flake8
            py.pkgs.black
            py.pkgs.isort
            py.pkgs.ipython
            pkgs.jupyter

            amici
            fides
            h5py
            petab
            pypesto

            # maybe propagate
            pkgs.swig
            pkgs.blas
            pkgs.pkg-config

            # not documented
            py.pkgs.openpyxl
            py.pkgs.emcee

            sbmlutils
            tellurium
          ];
        };
      }
    );
}
