#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${project_root}/build-windows"
dist_root="${project_root}/dist"
dependency_root="${RUNNER_TEMP:-${project_root}/.windows-dependencies}"
hamlib_source="${dependency_root}/jtdxhamlib"

: "${MINGW_PREFIX:?Run this script from an MSYS2 MINGW64 shell}"

if [[ ! -d "${hamlib_source}/.git" ]]; then
  git clone --depth 1 https://github.com/jtdx-project/jtdxhamlib.git "${hamlib_source}"
fi

pushd "${hamlib_source}"
./bootstrap
./configure \
  --prefix="${MINGW_PREFIX}" \
  --disable-static \
  --enable-shared \
  --without-readline \
  --without-indi \
  --without-cxx-binding \
  --disable-winradio \
  CC=gcc \
  CXX=g++ \
  CFLAGS="-O2 -fdata-sections -ffunction-sections" \
  LDFLAGS="-Wl,--gc-sections"
make -j2
make install
popd

cmake -S "${project_root}" -B "${build_root}" -G Ninja \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_INSTALL_PREFIX="${build_root}/stage" \
  -D CMAKE_PREFIX_PATH="${MINGW_PREFIX}" \
  -D WSJT_SKIP_MANPAGES=ON \
  -D WSJT_GENERATE_DOCS=OFF

cmake --build "${build_root}" --parallel 2
cmake -E chdir "${build_root}" cpack -G NSIS

mkdir -p "${dist_root}"
find "${build_root}" -maxdepth 1 -type f -name 'jtdx-ik0xbx-*.exe' -exec cp -f {} "${dist_root}/" \;
sha256sum "${dist_root}"/*.exe > "${dist_root}/SHA256SUMS.txt"
