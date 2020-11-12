
if [[ "$TRAVIS_OS_NAME" == "osx" ]]; then
  if [[ "$MB_PYTHON_VERSION" == "pypy3.6-7.3" || "$MB_PYTHON_VERSION" == "pypy3.7-7.3" ]]; then
    # for https://foss.heptapod.net/pypy/pypy/-/issues/3229
    # TODO remove when that is fixed
    brew install tcl-tk
  fi
  # these cause a conflict with built webp and libtiff
  brew remove --ignore-dependencies webp zstd xz libtiff
fi

if [[ "$MB_PYTHON_VERSION" == "pypy3.6-7.3" || "$MB_PYTHON_VERSION" == "pypy3.7-7.3" ]]; then
  if [[ "$TRAVIS_OS_NAME" != "macos-latest" ]]; then
    MB_ML_VER="2010"
    DOCKER_TEST_IMAGE="multibuild/xenial_$PLAT"
  else
    MB_PYTHON_OSX_VER="10.9"
  fi
fi

echo "::group::Install a virtualenv"
  source multibuild/common_utils.sh
  source multibuild/travis_steps.sh
  # can't use default 7.3.1 on macOS due to https://foss.heptapod.net/pypy/pypy/-/issues/3229
  LATEST_PP_7p3=7.3.3rc1
  pip install virtualenv
  before_install
echo "::endgroup::"

echo "::group::Build wheel"
  clean_code $REPO_DIR $BUILD_COMMIT
  build_wheel $REPO_DIR $PLAT
  ls -l "${GITHUB_WORKSPACE}/${WHEEL_SDIR}/"
echo "::endgroup::"

echo "::group::Test wheel"
  install_run $PLAT
echo "::endgroup::"
