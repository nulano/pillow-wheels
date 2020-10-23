# Define custom utilities
# Test for OS X with [ -n "$IS_OSX" ]

ARCHIVE_SDIR=pillow-depends-master

# Package versions for fresh source builds
FREETYPE_VERSION=2.10.4
LIBPNG_VERSION=1.6.37
ZLIB_VERSION=1.2.11
JPEG_VERSION=9d
OPENJPEG_VERSION=2.3.1
XZ_VERSION=5.2.5
TIFF_VERSION=4.1.0
LCMS2_VERSION=2.11
GIFLIB_VERSION=5.1.4
LIBWEBP_VERSION=1.1.0
BZIP2_VERSION=1.0.8
LIBXCB_VERSION=1.14

function pre_build {
    # Any stuff that you need to do before you start building the wheels
    # Runs in the root directory of this repository.
    curl -fsSL -o pillow-depends-master.zip https://github.com/python-pillow/pillow-depends/archive/master.zip
    untar pillow-depends-master.zip
    if [ -n "$IS_OSX" ]; then
        # Update to latest zlib for OS X build
        build_new_zlib
    fi

    if [ -n "$IS_OSX" ]; then
        ORIGINAL_BUILD_PREFIX=$BUILD_PREFIX
        ORIGINAL_PKG_CONFIG_PATH=$PKG_CONFIG_PATH
        BUILD_PREFIX=`dirname $(dirname $(which python))`
        PKG_CONFIG_PATH="$BUILD_PREFIX/lib/pkgconfig"
    fi
    build_simple xcb-proto 1.14.1 https://xcb.freedesktop.org/dist
    if [ -n "$IS_OSX" ]; then
        build_simple xproto 7.0.31 https://www.x.org/pub/individual/proto
        build_simple libXau 1.0.9 https://www.x.org/pub/individual/lib
        build_simple libpthread-stubs 0.4 https://xcb.freedesktop.org/dist
    else
        sed -i s/\${pc_sysrootdir\}// /usr/local/lib/pkgconfig/xcb-proto.pc
    fi
    build_simple libxcb $LIBXCB_VERSION https://xcb.freedesktop.org/dist
    if [ -n "$IS_OSX" ]; then
        BUILD_PREFIX=$ORIGINAL_BUILD_PREFIX
        PKG_CONFIG_PATH=$ORIGINAL_PKG_CONFIG_PATH
    fi
    
    # Custom flags to include both multibuild and jpeg defaults
    ORIGINAL_CFLAGS=$CFLAGS
    CFLAGS="$CFLAGS -g -O2"
    build_jpeg
    CFLAGS=$ORIGINAL_CFLAGS

    build_tiff
    build_libpng
    build_lcms2
    build_openjpeg

    if [ -z "$IS_OSX" ]; then
      CFLAGS="$CFLAGS -O3 -DNDEBUG"
      build_libwebp
      CFLAGS=$ORIGINAL_CFLAGS
    fi

    if [ -n "$IS_OSX" ]; then
        # Custom freetype build
        build_simple freetype $FREETYPE_VERSION https://download.savannah.gnu.org/releases/freetype tar.gz --with-harfbuzz=no --with-brotli=no
    else
        build_freetype
    fi
}

function run_tests_in_repo {
    # Run Pillow tests from within source repo
    python selftest.py
    pytest
}

EXP_CODECS="jpg jpg_2000 libtiff zlib"
EXP_MODULES="freetype2 littlecms2 pil tkinter webp"
EXP_FEATURES="transp_webp webp_anim webp_mux xcb"

function run_tests {
    if [ -n "$IS_OSX" ]; then
        brew install openblas
        echo -e "[openblas]\nlibraries = openblas\nlibrary_dirs = /usr/local/opt/openblas/lib" >> ~/.numpy-site.cfg
    fi
    pip install numpy

    mv ../pillow-depends-master/test_images/* ../Pillow/Tests/images

    # Runs tests on installed distribution from an empty directory
    (cd ../Pillow && run_tests_in_repo)
    # Test against expected codecs, modules and features
    local ret=0
    local codecs=$(python -c 'from PIL.features import *; print(" ".join(sorted(get_supported_codecs())))')
    if [ "$codecs" != "$EXP_CODECS" ]; then
        echo "Codecs should be: '$EXP_CODECS'; but are '$codecs'"
        ret=1
    fi
    local modules=$(python -c 'from PIL.features import *; print(" ".join(sorted(get_supported_modules())))')
    if [ "$modules" != "$EXP_MODULES" ]; then
        echo "Modules should be: '$EXP_MODULES'; but are '$modules'"
        ret=1
    fi
    local features=$(python -c 'from PIL.features import *; print(" ".join(sorted(get_supported_features())))')
    if [ "$features" != "$EXP_FEATURES" ]; then
        echo "Features should be: '$EXP_FEATURES'; but are '$features'"
        ret=1
    fi
    return $ret
}

function repair_wheelhouse {
    local wheelhouse=$1
    install_delocate
    delocate-listdeps $wheelhouse/*.whl # print delocation info
    delocate-wheel $wheelhouse/*.whl # copies library dependencies into wheel

}
