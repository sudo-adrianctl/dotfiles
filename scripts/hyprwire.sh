cd ~/lib/hyprwire
git checkout src
grep -rn "hwAppend" src      # should print nothing
rm -rf build
cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DCMAKE_C_COMPILER=/opt/gcc-15/bin/gcc-15 -DCMAKE_CXX_COMPILER=/opt/gcc-15/bin/g++-15
cmake --build build -j$(nproc) && sudo cmake --install build && sudo ldconfig
pkg-config --modversion hyprwire
