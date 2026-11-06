#/bin/bash

WAYLAND_PROTOCOLS_VERSION="1.49"
WORK_DIR="$HOME/lib"

cd $WORK_DIR
    
git clone https://gitlab.freedesktop.org/wayland/wayland-protocols.git
cd wayland-protocols

git fetch --tags
git checkout "$WAYLAND_PROTOCOLS_VERSION"

if [ -d build ]; then
    meson setup build --wipe \
        --prefix=/usr/local \
        -Dtests=false
else
    meson setup build \
        --prefix=/usr/local \
        -Dtests=false
fi

sudo ninja -C build install
