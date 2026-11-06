cd ~/lib
git clone --depth 1 --branch xkbcommon-1.11.0 https://github.com/xkbcommon/libxkbcommon.git
cd libxkbcommon
meson setup build --prefix=/usr/local -Denable-docs=false -Denable-tools=false
sudo ninja -C build install

cd ~/lib
git clone --depth 1 --branch 1.29.0 https://gitlab.freedesktop.org/libinput/libinput.git
cd libinput
meson setup build --prefix=/usr/local -Dtests=false -Ddocumentation=false -Ddebug-gui=false
sudo ninja -C build install

sudo apt install python3-attr python3-jinja2 python3-yaml libsystemd-dev
cd ~/lib
git ls-remote --tags https://gitlab.freedesktop.org/libinput/libei.git | tail -5   # pick the newest release tag
git clone --depth 1 --branch 1.5.0 https://gitlab.freedesktop.org/libinput/libei.git
cd libei
meson setup build --prefix=/usr/local -Dtests=disabled -Ddocumentation=[]
sudo ninja -C build install
