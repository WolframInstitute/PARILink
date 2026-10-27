#!/usr/bin/env bash
# Build GP and GMP from verified sources. No software is installed on the host.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
python3 scripts/runtime.py fetch
pari_version=$(python3 scripts/runtime.py version pari)
gmp_version=$(python3 scripts/runtime.py version gmp)

case "$(uname -s)/$(uname -m)" in
    Darwin/arm64) system=MacOSX-ARM64 ;;
    Darwin/x86_64) system=MacOSX-x86-64 ;;
    Linux/x86_64) system=Linux-x86-64 ;;
    Linux/aarch64) system=Linux-ARM64 ;;
    MINGW*/x86_64) system=Windows-x86-64 ;;
    *) echo 'Unsupported build platform' >&2; exit 1 ;;
esac

# Compile in a short, space-free path; the installed runtime is tested with spaces.
work=$(mktemp -d /tmp/parilink-build.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
output="$root/build/runtimes/$system"
mkdir -p "$output"
tar -xf "build/runtime-sources/gmp-$gmp_version.tar.xz" -C "$work"
tar -xf "build/runtime-sources/pari-$pari_version.tar.gz" -C "$work"

unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH CPPFLAGS LDFLAGS CFLAGS
export LC_ALL=C
export CC=cc
export CFLAGS=-O2
gmp_options=(--prefix="$work/gmp" --disable-shared --enable-static --with-pic ABI=64)
case "$system" in
    *-x86-64)
        # Baseline x86-64 instructions; GMP dispatches to faster code at runtime.
        export CFLAGS='-O2 -march=x86-64 -mtune=generic'
        gmp_options+=(--enable-fat)
        ;;
    Linux-ARM64) export CFLAGS='-O2 -march=armv8-a' ;;
esac
case "$system" in
    MacOSX-x86-64)
        export MACOSX_DEPLOYMENT_TARGET=13.0
        export CFLAGS="$CFLAGS -arch x86_64"
        ;;
    MacOSX-ARM64) export MACOSX_DEPLOYMENT_TARGET=13.0 ;;
    Windows-*) export CC=gcc LDFLAGS='-static -static-libgcc' ;;
esac

graphics=svg
if [[ $system == Windows-* ]]; then graphics=win32; fi

jobs=${PARILINK_BUILD_JOBS:-4}
[[ $jobs =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid PARILINK_BUILD_JOBS' >&2; exit 1; }
printf 'Building GP %s and GMP %s for %s...\n' "$pari_version" "$gmp_version" "$system"
trap 'tail -80 "$output/build.log" >&2' ERR
(
    cd "$work/gmp-$gmp_version"
    ./configure "${gmp_options[@]}"
    make -j "$jobs"
    make -j "$jobs" check
    make install
    cd "$work/pari-$pari_version"
    ./Configure --static --without-readline --mt=pthread --graphic="$graphics" \
        --with-gmp="$work/gmp" --prefix="$work/install"
    cp O*/config.log "$output/configure.log"
    # Configure can silently fall back when an optional dependency is unusable.
    grep -q 'Using GNU MP, version' "$output/build.log"
    grep -q 'Using mt engine pthread' "$output/build.log"
    # Static GMP needs no search path back to the temporary build directory.
    make -j "$jobs" gp RUNPTH= RUNPTH_FINAL=
) > "$output/build.log" 2>&1

runtime="$output/$system"
rm -rf -- "$runtime"
mkdir -p "$runtime/licenses/pari" "$runtime/licenses/gmp"
executable=gp
if [[ $system == Windows-* ]]; then executable=gp.exe; fi
# The top-level gp is a symlink on Unix; copy the binary, never the symlink.
install -m 755 "$work/pari-$pari_version/$executable" "$runtime/$executable"
cp "$work/pari-$pari_version/COPYING" "$runtime/licenses/pari/"
cp "$work/gmp-$gmp_version"/COPYING* "$runtime/licenses/gmp/"
"$CC" --version > "$runtime/toolchain.txt"
if [[ $system == Windows-* ]]; then
    for library in crt winpthreads; do
        cp -R "$MINGW_PREFIX/share/licenses/$library" "$runtime/licenses/"
    done
    gcc_license=
    for library in libgcc gcc-libs gcc; do
        if [[ -f $MINGW_PREFIX/share/licenses/$library/COPYING.RUNTIME ]]; then
            gcc_license=$library
            break
        fi
    done
    [[ -n $gcc_license ]] || { echo 'GCC runtime license was not found' >&2; exit 1; }
    cp -R "$MINGW_PREFIX/share/licenses/$gcc_license" "$runtime/licenses/"
    pacman -Q >> "$runtime/toolchain.txt"
fi

python3 scripts/runtime.py pack "$system"
