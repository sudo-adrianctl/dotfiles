#!/bin/bash
# Idempotent Hyprland 0.56.2 + deps installer for Debian 13 (trixie).
# Builds into /usr/local; reuses clones under $HOME/lib when present.
set -euo pipefail

FORCE="${FORCE:-0}"
WORK_DIR="${HOME}/lib"
PREFIX="/usr/local"
GCC_PREFIX="/opt/gcc-15"
GCC_TAG="releases/gcc-15.2.0"
SHIM_DIR="${WORK_DIR}/build-shims"
SHIM_HPP="${SHIM_DIR}/ranges_starts_with_shim.hpp"

# Pinned versions (match what already works on this machine)
LUA_VERSION="5.5.1"
WAYLAND_VERSION="1.25.91"
WAYLAND_PROTOCOLS_VERSION="1.49"
XKBCOMMON_VERSION="1.11.0"
LIBINPUT_VERSION="1.29.0"
LIBEI_VERSION="1.5.0"
HYPRLAND_PROTOCOLS_VERSION="0.7.0"
HYPRWAYLAND_SCANNER_VERSION="0.4.6"
HYPRUTILS_VERSION="0.14.3"
HYPRGRAPHICS_VERSION="0.5.1"
HYPRLANG_VERSION="0.6.8"
HYPRCURSOR_VERSION="0.1.13"
AQUAMARINE_VERSION="0.14.0"
HYPRWIRE_VERSION="0.3.1"
HYPRTOOLKIT_VERSION="0.6.0"
HYPRPAPER_VERSION="0.8.5"
XDPH_VERSION="v1.5.0"
HYPRLAND_VERSION="0.56.2"

# Floors from ~/lib/Hyprland/CMakeLists.txt (build from source when apt is older)
WAYLAND_SERVER_MIN="1.22.91"
WAYLAND_PROTOCOLS_MIN="1.49"
XKBCOMMON_MIN="1.11.0"
LIBINPUT_MIN="1.29"

mkdir -p "${WORK_DIR}" "${SHIM_DIR}"

# --- apt deps: everything Hyprland/aquamarine/toolkit/paper/portal need from distro ---
# Covers CMakeLists pkg_check_modules + XWayland xcb-* + hyprtoolkit (iniparser/abseil) + portal.
sudo apt update
sudo apt install -y \
  meson wget curl git python3 build-essential ninja-build cmake cmake-extras \
  gettext gettext-base fontconfig libfontconfig-dev libffi-dev libxml2-dev \
  libdrm-dev libxkbcommon-x11-dev libxkbregistry-dev libxkbcommon-dev \
  libpixman-1-dev libudev-dev libseat-dev seatd \
  libegl-dev libgles2 libegl1-mesa-dev libgl1-mesa-dev glslang-tools glslang-dev \
  libinput-bin libinput-dev \
  libavutil-dev libavcodec-dev libavformat-dev \
  libxcb1-dev libxcb-dri3-dev libxcb-composite0-dev libxcb-ewmh2 libxcb-ewmh-dev \
  libxcb-present-dev libxcb-icccm4-dev libxcb-render0-dev libxcb-render-util0-dev \
  libxcb-res0-dev libxcb-xinput-dev libxcb-xfixes0-dev libxcb-errors-dev \
  libtomlplusplus3 libtomlplusplus-dev libre2-dev libpugixml-dev \
  libcairo2-dev libpango1.0-dev libglib2.0-dev uuid-dev \
  libjpeg-dev libpng-dev libwebp-dev libmagic-dev librsvg2-dev libzip-dev \
  libwayland-dev libgbm-dev libdisplay-info-dev hwdata \
  graphviz bison flex libxcursor-dev libmuparser-dev liblcms2-dev \
  libei-dev libreadline-dev libiniparser-dev libabsl-dev \
  libgmp-dev libmpfr-dev libmpc-dev libisl-dev texinfo \
  pkg-config libdbus-1-dev qt6-base-dev qt6-wayland \
  libpipewire-0.3-dev libspa-0.2-dev libsdbus-c++-dev systemd

# --- env / job count ---
# ~8 GiB RAM: never use -j$(nproc); Cap parallelism so link/compile peaks stay under available memory.
MEM_AVAILABLE_KB="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
if [[ "${MEM_AVAILABLE_KB}" -lt 3145728 ]]; then
  JOBS=1
else
  JOBS=2
fi
echo "MemAvailable=${MEM_AVAILABLE_KB} kB → using -j${JOBS}"

export PATH="${GCC_PREFIX}/bin:${PREFIX}/bin:${PATH}"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PREFIX}/lib/x86_64-linux-gnu/pkgconfig:${PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="${GCC_PREFIX}/lib64:${PREFIX}/lib:${PREFIX}/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
export CMAKE_PREFIX_PATH="${PREFIX}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
export CC="${GCC_PREFIX}/bin/gcc-15"
export CXX="${GCC_PREFIX}/bin/g++-15"

need_pkg() {
  # return 0 if we should build (missing / wrong version / FORCE=1)
  local pc="$1" want="$2"
  if [[ "${FORCE}" == "1" ]]; then
    return 0
  fi
  if pkg-config --exists "${pc}" 2>/dev/null; then
    local got
    got="$(pkg-config --modversion "${pc}")"
    if [[ "${got}" == "${want}" ]]; then
      echo "skip ${pc} ${got} (already installed)"
      return 1
    fi
    echo "${pc}: have ${got}, want ${want} — rebuilding"
  fi
  return 0
}

# return 0 if pkg missing or older than min (Hyprland CMake floors)
need_pkg_at_least() {
  local pc="$1" min="$2"
  if [[ "${FORCE}" == "1" ]]; then
    return 0
  fi
  if pkg-config --exists "${pc} >= ${min}" 2>/dev/null; then
    echo "skip ${pc} $(pkg-config --modversion "${pc}") (>= ${min})"
    return 1
  fi
  return 0
}

need_cmd() {
  local bin="$1"
  if [[ "${FORCE}" == "1" ]]; then
    return 0
  fi
  if command -v "${bin}" >/dev/null 2>&1; then
    echo "skip ${bin} (already on PATH)"
    return 1
  fi
  return 0
}

# Fail fast if anything required by ~/lib/Hyprland/CMakeLists.txt is still missing.
assert_hyprland_deps() {
  local missing=0
  local req
  # REQUIRED pkg-config modules from Hyprland CMakeLists.txt (+ hyprctl/hyprpm extras)
  local -a reqs=(
    "aquamarine >= 0.9.3"
    "hyprlang >= 0.6.7"
    "hyprcursor >= 0.1.7"
    "hyprutils >= 0.14.0"
    "hyprgraphics >= 0.5.1"
    "xkbcommon >= ${XKBCOMMON_MIN}"
    "uuid"
    "wayland-server >= ${WAYLAND_SERVER_MIN}"
    "wayland-protocols >= ${WAYLAND_PROTOCOLS_MIN}"
    "wayland-scanner"
    "cairo" "pango" "pangocairo" "pixman-1" "xcursor" "libdrm"
    "libinput >= ${LIBINPUT_MIN}"
    "libeis-1.0" "gbm" "gio-2.0" "re2" "muparser" "lcms2"
    "lua5.5"
    "hyprwayland-scanner"
    "hyprwire"
    "xcb" "xcb-render" "xcb-xfixes" "xcb-icccm" "xcb-composite" "xcb-res" "xcb-errors"
    "tomlplusplus" "readline"
  )
  echo "Checking Hyprland dependency closure..."
  for req in "${reqs[@]}"; do
    if pkg-config --exists ${req} 2>/dev/null; then
      local name="${req%% *}"
      echo "  OK  ${req} → $(pkg-config --modversion "${name}")"
    else
      echo "  MISS ${req}"
      missing=1
    fi
  done
  if ! command -v hyprwayland-scanner >/dev/null 2>&1; then
    echo "  MISS hyprwayland-scanner binary"
    missing=1
  fi
  if [[ "${missing}" -ne 0 ]]; then
    echo "Hyprland dependencies incomplete; aborting before configure." >&2
    exit 1
  fi
}

ensure_repo() {
  # Clone or update an existing $WORK_DIR checkout to the pinned ref.
  local dir="$1" url="$2" ref="$3"
  if [[ -d "${dir}/.git" ]]; then
    echo "reusing ${dir} → ${ref}"
    git -C "${dir}" fetch --depth 1 origin "refs/tags/${ref}:refs/tags/${ref}" 2>/dev/null \
      || git -C "${dir}" fetch --depth 1 origin "${ref}" 2>/dev/null \
      || git -C "${dir}" fetch --tags --depth 1 origin 2>/dev/null \
      || true
    git -C "${dir}" checkout -f "${ref}"
  else
    rm -rf "${dir}"
    git clone --depth 1 --branch "${ref}" "${url}" "${dir}"
  fi
}

cmake_build_install() {
  local dir="$1"
  shift
  cd "${dir}"
  if [[ "${FORCE}" == "1" ]]; then
    rm -rf build
  fi
  cmake -B build -S . \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_C_COMPILER="${CC}" \
    -DCMAKE_CXX_COMPILER="${CXX}" \
    "$@"
  cmake --build build -j"${JOBS}"
  sudo cmake --install build
  sudo ldconfig
}

meson_build_install() {
  local dir="$1"
  shift
  cd "${dir}"
  if [[ "${FORCE}" == "1" && -d build ]]; then
    rm -rf build
  fi
  if [[ -d build ]]; then
    meson setup build --reconfigure --prefix="${PREFIX}" "$@"
  else
    meson setup build --prefix="${PREFIX}" "$@"
  fi
  meson compile -C build -j "${JOBS}"
  sudo meson install -C build
  sudo ldconfig
}

# --- GCC 15 ---
# Hyprland 0.56 needs C++26; system g++ on Debian 13 is too old. Use GCC 15 at /opt/gcc-15.
if [[ ! -x "${GCC_PREFIX}/bin/g++-15" ]]; then
  echo "GCC 15 missing at ${GCC_PREFIX}; building ${GCC_TAG}..."
  sudo apt install -y libgmp-dev libmpfr-dev libmpc-dev libisl-dev flex bison texinfo build-essential
  ensure_repo "${WORK_DIR}/gcc-15" "https://gcc.gnu.org/git/gcc.git" "${GCC_TAG}"
  mkdir -p "${WORK_DIR}/gcc-15/build"
  cd "${WORK_DIR}/gcc-15/build"
  if [[ ! -f Makefile ]]; then
    ../configure --prefix="${GCC_PREFIX}" --program-suffix=-15 \
      --enable-languages=c,c++ --disable-multilib --disable-bootstrap
  fi
  make -j"${JOBS}"
  sudo make install
  echo "${GCC_PREFIX}/lib64" | sudo tee /etc/ld.so.conf.d/gcc-15.conf >/dev/null
  sudo ldconfig
fi
"${GCC_PREFIX}/bin/g++-15" --version

# Shim: GCC 15 libstdc++ lacks std::ranges::starts_with (GCC 16+). Inject via -include; do not edit Hyprland.
if [[ ! -f "${SHIM_HPP}" ]]; then
  cat > "${SHIM_HPP}" <<'EOF'
#pragma once
/* GCC 15 libstdc++ lacks std::ranges::starts_with (added in GCC 16).
 * Injected via -include so Hyprland sources stay unmodified. */
#include <ranges>
#include <iterator>
#include <utility>

#if !defined(__cpp_lib_ranges_starts_ends_with)
namespace std {
namespace ranges {
struct __starts_with_fn {
  template <std::input_iterator I1, std::sentinel_for<I1> S1,
            std::input_iterator I2, std::sentinel_for<I2> S2,
            class Pred = ranges::equal_to, class Proj1 = identity, class Proj2 = identity>
  constexpr bool operator()(I1 first1, S1 last1, I2 first2, S2 last2,
                            Pred pred = {}, Proj1 proj1 = {}, Proj2 proj2 = {}) const {
    return ranges::mismatch(std::move(first1), last1, std::move(first2), last2,
                            std::move(pred), std::move(proj1), std::move(proj2)).in2 == last2;
  }
  template <ranges::input_range R1, ranges::input_range R2,
            class Pred = ranges::equal_to, class Proj1 = identity, class Proj2 = identity>
  constexpr bool operator()(R1&& r1, R2&& r2, Pred pred = {}, Proj1 proj1 = {}, Proj2 proj2 = {}) const {
    return (*this)(ranges::begin(r1), ranges::end(r1), ranges::begin(r2), ranges::end(r2),
                   std::move(pred), std::move(proj1), std::move(proj2));
  }
};
inline constexpr __starts_with_fn starts_with{};
} // namespace ranges
} // namespace std
#endif
EOF
fi

# --- Lua 5.5 (Hyprland pkg_search_module looks for lua5.5) ---
if need_pkg lua5.5 "${LUA_VERSION}"; then
  LUA_DIR="lua-${LUA_VERSION}"
  cd /tmp
  curl -fsSL -R -O "https://www.lua.org/ftp/${LUA_DIR}.tar.gz"
  rm -rf "${LUA_DIR}"
  tar zxf "${LUA_DIR}.tar.gz"
  cd "${LUA_DIR}"
  make all MYCFLAGS="-fPIC" CC="${CC}" -j"${JOBS}"
  sudo make install INSTALL_TOP="${PREFIX}"
  sudo tee "${PREFIX}/lib/pkgconfig/lua5.5.pc" >/dev/null <<EOF
prefix=${PREFIX}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: Lua
Description: An Extensible Extension Language
Version: ${LUA_VERSION}
Requires:
Libs: -L\${libdir} -llua -lm -ldl
Cflags: -I\${includedir}
EOF
  "${PREFIX}/bin/lua" -v
fi

# --- base libs / protocols (build from source when apt is too old for Hyprland floors) ---
# wayland-server >= 1.22.91 is REQUIRED by Hyprland; scanner pin is what we ship in /usr/local.
NEED_WAYLAND_SCANNER=0
NEED_WAYLAND_LIBS=0
if need_pkg wayland-scanner "${WAYLAND_VERSION}"; then NEED_WAYLAND_SCANNER=1; fi
if need_pkg_at_least wayland-server "${WAYLAND_SERVER_MIN}"; then NEED_WAYLAND_LIBS=1; fi
if [[ "${NEED_WAYLAND_SCANNER}" -eq 1 || "${NEED_WAYLAND_LIBS}" -eq 1 ]]; then
  ensure_repo "${WORK_DIR}/wayland" \
    "https://gitlab.freedesktop.org/wayland/wayland.git" "${WAYLAND_VERSION}"
  WAYLAND_LIBS=false
  if [[ "${NEED_WAYLAND_LIBS}" -eq 1 ]]; then
    WAYLAND_LIBS=true
  fi
  meson_build_install "${WORK_DIR}/wayland" \
    -Dscanner=true "-Dlibraries=${WAYLAND_LIBS}" -Dtests=false -Ddocumentation=false
fi

if need_pkg wayland-protocols "${WAYLAND_PROTOCOLS_VERSION}"; then
  ensure_repo "${WORK_DIR}/wayland-protocols" \
    "https://gitlab.freedesktop.org/wayland/wayland-protocols.git" \
    "${WAYLAND_PROTOCOLS_VERSION}"
  meson_build_install "${WORK_DIR}/wayland-protocols" -Dtests=false
fi

if need_pkg xkbcommon "${XKBCOMMON_VERSION}"; then
  ensure_repo "${WORK_DIR}/libxkbcommon" \
    "https://github.com/xkbcommon/libxkbcommon.git" "xkbcommon-${XKBCOMMON_VERSION}"
  meson_build_install "${WORK_DIR}/libxkbcommon" -Denable-docs=false
fi

if need_pkg libinput "${LIBINPUT_VERSION}"; then
  ensure_repo "${WORK_DIR}/libinput" \
    "https://gitlab.freedesktop.org/libinput/libinput.git" "${LIBINPUT_VERSION}"
  meson_build_install "${WORK_DIR}/libinput" \
    -Dtests=false -Ddocumentation=false -Ddebug-gui=false
fi

if need_pkg libei-1.0 "${LIBEI_VERSION}"; then
  ensure_repo "${WORK_DIR}/libei" \
    "https://gitlab.freedesktop.org/libinput/libei.git" "${LIBEI_VERSION}"
  meson_build_install "${WORK_DIR}/libei" -Dtests=disabled '-Ddocumentation=[]'
fi

# --- Hypr libs ---
if need_pkg hyprland-protocols "${HYPRLAND_PROTOCOLS_VERSION}"; then
  ensure_repo "${WORK_DIR}/hyperland-protocols" \
    "https://github.com/hyprwm/hyprland-protocols.git" "v${HYPRLAND_PROTOCOLS_VERSION}"
  meson_build_install "${WORK_DIR}/hyperland-protocols"
fi

if need_pkg hyprwayland-scanner "${HYPRWAYLAND_SCANNER_VERSION}"; then
  ensure_repo "${WORK_DIR}/hyprwayland-scanner" \
    "https://github.com/hyprwm/hyprwayland-scanner.git" "v${HYPRWAYLAND_SCANNER_VERSION}"
  cmake_build_install "${WORK_DIR}/hyprwayland-scanner"
fi

if need_pkg hyprutils "${HYPRUTILS_VERSION}"; then
  ensure_repo "${WORK_DIR}/hyprutils" \
    "https://github.com/hyprwm/hyprutils.git" "v${HYPRUTILS_VERSION}"
  cmake_build_install "${WORK_DIR}/hyprutils"
fi

if need_pkg hyprgraphics "${HYPRGRAPHICS_VERSION}"; then
  ensure_repo "${WORK_DIR}/hyprgraphics" \
    "https://github.com/hyprwm/hyprgraphics.git" "v${HYPRGRAPHICS_VERSION}"
  cmake_build_install "${WORK_DIR}/hyprgraphics"
fi

if need_pkg hyprlang "${HYPRLANG_VERSION}"; then
  ensure_repo "${WORK_DIR}/hyprlang" \
    "https://github.com/hyprwm/hyprlang.git" "v${HYPRLANG_VERSION}"
  cmake_build_install "${WORK_DIR}/hyprlang"
fi

if need_pkg hyprcursor "${HYPRCURSOR_VERSION}"; then
  ensure_repo "${WORK_DIR}/hyprcursor" \
    "https://github.com/hyprwm/hyprcursor.git" "v${HYPRCURSOR_VERSION}"
  cmake_build_install "${WORK_DIR}/hyprcursor"
fi

if need_pkg aquamarine "${AQUAMARINE_VERSION}"; then
  ensure_repo "${WORK_DIR}/aquamarine" \
    "https://github.com/hyprwm/aquamarine.git" "v${AQUAMARINE_VERSION}"
  cmake_build_install "${WORK_DIR}/aquamarine"
fi

if need_pkg hyprwire "${HYPRWIRE_VERSION}"; then
  ensure_repo "${WORK_DIR}/hyprwire" \
    "https://github.com/hyprwm/hyprwire.git" "v${HYPRWIRE_VERSION}"
  cmake_build_install "${WORK_DIR}/hyprwire"
fi

# --- optional extras: portal / toolkit / paper ---
if need_cmd xdg-desktop-portal-hyprland; then
  ensure_repo "${WORK_DIR}/xdg-desktop-portal-hyprland" \
    "https://github.com/hyprwm/xdg-desktop-portal-hyprland.git" "${XDPH_VERSION}"
  meson_build_install "${WORK_DIR}/xdg-desktop-portal-hyprland"
fi

if need_pkg hyprtoolkit "${HYPRTOOLKIT_VERSION}"; then
  ensure_repo "${WORK_DIR}/hyprtoolkit" \
    "https://github.com/hyprwm/hyprtoolkit.git" "v${HYPRTOOLKIT_VERSION}"
  cmake_build_install "${WORK_DIR}/hyprtoolkit"
fi

if need_cmd hyprpaper; then
  ensure_repo "${WORK_DIR}/hyprpaper" \
    "https://github.com/hyprwm/hyprpaper.git" "v${HYPRPAPER_VERSION}"
  cmake_build_install "${WORK_DIR}/hyprpaper"
fi

# --- Hyprland (shim via -include; never patch sources) ---
# Full dependency closure from ~/lib/Hyprland/CMakeLists.txt must already be satisfied.
assert_hyprland_deps

if need_pkg hyprland "${HYPRLAND_VERSION}"; then
  ensure_repo "${WORK_DIR}/Hyprland" \
    "https://github.com/hyprwm/Hyprland.git" "v${HYPRLAND_VERSION}"
  # udis86 (+ optional tracy/protocols) come from submodules — do not patch sources
  git -C "${WORK_DIR}/Hyprland" submodule update --init --recursive --depth 1 || \
    git -C "${WORK_DIR}/Hyprland" submodule update --init --recursive
  cmake_build_install "${WORK_DIR}/Hyprland" \
    "-DCMAKE_CXX_FLAGS=-include ${SHIM_HPP}"
fi

sudo ldconfig
echo "Installed Hyprland:"
Hyprland --version
