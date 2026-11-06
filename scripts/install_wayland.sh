#/bin/bash

WAYLAND_VERSION="1.25.91"
WORK_DIR="$HOME/lib"

cd "$WORK_DIR"

git clone https://gitlab.freedesktop.org/wayland/wayland.git
cd wayland
git fetch --tags
git checkout "$WAYLAND_VERSION"

if [ -d build ]; then
    meson setup build --wipe \
        --prefix=/usr/local \
        -Dscanner=true \
        -Dlibraries=false \
        -Dtests=false \
        -Ddocumentation=false
else
    meson setup build \
        --prefix=/usr/local \
        -Dscanner=true \
        -Dlibraries=false \
        -Dtests=false \
        -Ddocumentation=false
fi

sudo ninja -C build install
sudo ldconfig
