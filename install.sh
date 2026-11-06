#/bin/bash
set -e

sudo apt update
sudo apt install -y meson wget build-essential ninja-build cmake-extras cmake gettext gettext-base fontconfig libfontconfig-dev libffi-dev libxml2-dev libdrm-dev libxkbcommon-x11-dev libxkbregistry-dev libxkbcommon-dev libpixman-1-dev libudev-dev libseat-dev seatd libxcb-dri3-dev libegl-dev libgles2 libegl1-mesa-dev glslang-tools libinput-bin libinput-dev libxcb-composite0-dev libavutil-dev libavcodec-dev libavformat-dev libxcb-ewmh2 libxcb-ewmh-dev libxcb-present-dev libxcb-icccm4-dev libxcb-render-util0-dev libxcb-res0-dev libxcb-xinput-dev libtomlplusplus3 libre2-dev libpugixml-dev libcairo2-dev libpango1.0-dev libjpeg-dev libwebp-dev libmagic-dev librsvg2-dev libzip-dev libtomlplusplus-dev libwayland-dev libgbm-dev libdisplay-info-dev hwdata graphviz glslang-dev bison flex libxcursor-dev libmuparser-dev liblcms2-dev libei-dev libreadline-dev

WORK_DIR="$HOME/lib"
LUA_VERSION="5.5.1"
HYPERLAND_PROTOCOL_VERSION="0.7.1"
HYPERWAYLAND_SCANNER_VERSION="0.4.6"
HYPERUTILS_VERSION="0.14.3"
HYPRGRAPHICS_VERSION="0.5.1"
HYPRLANG_VERSION="0.6.8"
HYPRCURSOR_VERSION="0.1.13"
AQUAMARINE_VERSION="0.14.0"
XDPH_VERSION="main"
HYPRWIRE_VERSION="main"
HYPRTOOLKIT_VERSION="main"
HYPRPAPER_VERSION="main"
PREFIX="/usr/local"


wayland
meson setup build --wipe \
    --prefix=/usr/local \
    -Dscanner=true \
    -Dlibraries=false \
    -Dtests=false \
    -Ddocumentation=false

LUA="lua-$LUA_VERSION"
if ! command -v "lua" >/dev/null 2>&1; then
 echo "Lua $LUA_VERSION is not installed. Installing..."
 cd /tmp
 curl -L -R -O "https://www.lua.org/ftp/$LUA.tar.gz"
 tar zxf "$LUA.tar.gz"
 cd $LUA
 make all test
 sudo make install INSTALL_TOP="$PREFIX" 
 echo "Lua installation completed."
 "$PREFIX/bin/lua" -v 
else
 echo "Lua 5.5 is already installed."
fi

if dpkg -s wayland-protocols >/dev/null 2>&1; then
    dpkg-query -W -f='wayland-protocols installed version: ${Version}\n' wayland-protocols
else
    echo "wayland-protocols is not installed. Installing..."
    sudo apt install -y wayland-protocols
fi

if pkg-config --exists hyprland-protocols; then
    INSTALLED=$(pkg-config --modversion hyprland-protocols)
    echo "wayland-protocols installed version: $INSTALLED"
else
    git clone --depth 1 --branch "v$HYPERLAND_PROTOCOL_VERSION" https://github.com/hyprwm/hyprland-protocols.git "$WORK_DIR/hyperland-protocols"
    cd "$WORK_DIR/hyperland-protocols"
    meson setup build --prefix="$PREFIX"
    meson compile -C build
    sudo meson install -C build
    echo "hyperland-protocols installation completed."
fi

if pkg-config --exists hyprwayland-scanner; then
   INSTALLED=$(pkg-config --modversion hyprwayland-scanner)
   echo "hyprwayland-scanner installed version: $INSTALLED"
else
   git clone --depth 1 --branch "v$HYPERWAYLAND_SCANNER_VERSION" https://github.com/hyprwm/hyprwayland-scanner.git "$WORK_DIR/hyprwayland-scanner"
   cd "$WORK_DIR/hyprwayland-scanner"
   cmake -B build -S . -DCMAKE_INSTALL_PREFIX="$PREFIX"
   cmake --build build -j"$(nproc)"
   sudo cmake --install build
   echo "hyprwayland-scanner installation completed."
fi


if pkg-config --exists hyprutils; then
   INSTALLED=$(pkg-config --modversion hyprutils)
   echo "hyprutils installed version: $INSTALLED"
else
   git clone --depth 1 --branch "v$HYPERUTILS_VERSION" https://github.com/hyprwm/hyprutils.git "$WORK_DIR/hyprutils"
   cd "$WORK_DIR/hyprutils"
   cmake -B build -S . -DCMAKE_INSTALL_PREFIX="$PREFIX"
   cmake --build build -j"$(nproc)"
   sudo cmake --install build
   sudo ldconfig
   echo "hyprutils installation completed."
fi

if pkg-config --exists hyprgraphics; then
    INSTALLED=$(pkg-config --modversion hyprgraphics)
    echo "hyprgraphics installed version: $INSTALLED"
else
    git clone --depth 1 --branch "v$HYPRGRAPHICS_VERSION" \
        https://github.com/hyprwm/hyprgraphics.git \
        "$WORK_DIR/hyprgraphics"

    cd "$WORK_DIR/hyprgraphics"

    cmake -B build -S . -DCMAKE_INSTALL_PREFIX="$PREFIX"
    cmake --build build -j"$(nproc)"
    sudo cmake --install build
    sudo ldconfig

    echo "hyprgraphics installation completed."
fi


if pkg-config --exists hyprlang; then
    INSTALLED=$(pkg-config --modversion hyprlang)
    echo "hyprlang installed version: $INSTALLED"
else
    git clone --depth 1 --branch "v$HYPRLANG_VERSION" \
        https://github.com/hyprwm/hyprlang.git \
        "$WORK_DIR/hyprlang"

    cd "$WORK_DIR/hyprlang"

    cmake -B build -S . -DCMAKE_INSTALL_PREFIX="$PREFIX"
    cmake --build build -j"$(nproc)"
    sudo cmake --install build
    sudo ldconfig

    echo "hyprlang installation completed."
fi

if pkg-config --exists hyprcursor; then
    INSTALLED=$(pkg-config --modversion hyprcursor)
    echo "hyprcursor installed version: $INSTALLED"
else
    git clone --depth 1 --branch "v$HYPRCURSOR_VERSION" \
        https://github.com/hyprwm/hyprcursor.git \
        "$WORK_DIR/hyprcursor"

    cd "$WORK_DIR/hyprcursor"

    cmake -B build -S . -DCMAKE_INSTALL_PREFIX="$PREFIX"
    cmake --build build -j"$(nproc)"
    sudo cmake --install build
    sudo ldconfig

    echo "hyprcursor installation completed."
fi

if pkg-config --exists aquamarine; then
    INSTALLED=$(pkg-config --modversion aquamarine)
    echo "aquamarine installed version: $INSTALLED"
else
    git clone --depth 1 --branch "v$AQUAMARINE_VERSION" \
        https://github.com/hyprwm/aquamarine.git \
        "$WORK_DIR/aquamarine"

    cd "$WORK_DIR/aquamarine"

    cmake -B build -S . -DCMAKE_INSTALL_PREFIX="$PREFIX"
    cmake --build build -j"$(nproc)"
    sudo cmake --install build
    sudo ldconfig

    echo "aquamarine installation completed."
fi

if command -v xdg-desktop-portal-hyprland >/dev/null 2>&1; then
    echo "xdg-desktop-portal-hyprland is already installed."
else
    git clone --depth 1 --branch "$XDPH_VERSION" \
        https://github.com/hyprwm/xdg-desktop-portal-hyprland.git \
        "$WORK_DIR/xdg-desktop-portal-hyprland"

    cd "$WORK_DIR/xdg-desktop-portal-hyprland"

    meson setup build --prefix="$PREFIX"
    meson compile -C build
    sudo meson install -C build
    sudo ldconfig

    echo "xdg-desktop-portal-hyprland installation completed."
fi

if pkg-config --exists hyprwire; then
    INSTALLED=$(pkg-config --modversion hyprwire)
    echo "hyprwire installed version: $INSTALLED"
else
    git clone --depth 1 --branch "$HYPRWIRE_VERSION" \
        https://github.com/hyprwm/hyprwire.git \
        "$WORK_DIR/hyprwire"

    cd "$WORK_DIR/hyprwire"

    cmake -B build -S . -DCMAKE_INSTALL_PREFIX="$PREFIX"
    cmake --build build -j"$(nproc)"
    sudo cmake --install build
    sudo ldconfig

    echo "hyprwire installation completed."
fi

if pkg-config --exists hyprtoolkit; then
    INSTALLED=$(pkg-config --modversion hyprtoolkit)
    echo "hyprtoolkit installed version: $INSTALLED"
else
    git clone --depth 1 --branch "$HYPRTOOLKIT_VERSION" \
        https://github.com/hyprwm/hyprtoolkit.git \
        "$WORK_DIR/hyprtoolkit"

    cd "$WORK_DIR/hyprtoolkit"

    cmake -B build -S . -DCMAKE_INSTALL_PREFIX="$PREFIX"
    cmake --build build -j"$(nproc)"
    sudo cmake --install build
    sudo ldconfig

    echo "hyprtoolkit installation completed."
fi

if command -v hyprpaper >/dev/null 2>&1; then
    echo "hyprpaper is already installed."
else
    git clone --depth 1 --branch "$HYPRPAPER_VERSION" \
        https://github.com/hyprwm/hyprpaper.git \
        "$WORK_DIR/hyprpaper"

    cd "$WORK_DIR/hyprpaper"

    cmake -B build -S . -DCMAKE_INSTALL_PREFIX="$PREFIX"
    cmake --build build -j"$(nproc)"
    sudo cmake --install build
    sudo ldconfig

    echo "hyprpaper installation completed."
fi
