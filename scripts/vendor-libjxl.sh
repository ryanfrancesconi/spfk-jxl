#!/bin/sh
# Copies libjxl's encoder, decoder, CMS and thread runner sources, and highway, skcms and brotli at the commits libjxl
# pins, from a checkout into Sources/libjxl and Sources/libbrotli, with only the headers they include. The four headers
# CMake generates come from a configured build directory. License files go to Licenses/.
#
# Usage: scripts/vendor-libjxl.sh <libjxl checkout at a release tag, submodules initialized> <its CMake build directory>

set -eu

SRC="$(cd "$1" && pwd)"
BUILD="$(cd "$2" && pwd)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JXL="$ROOT/Sources/libjxl"
BROTLI="$ROOT/Sources/libbrotli"
LIST="$(mktemp)"
GEN="$(mktemp -d)"

rm -rf "$JXL" "$BROTLI"
mkdir -p "$JXL" "$BROTLI" "$ROOT/Licenses" "$GEN/jxl"

for header in version.h jxl_export.h jxl_cms_export.h jxl_threads_export.h; do
    cp "$BUILD/lib/include/jxl/$header" "$GEN/jxl/"
done

cd "$SRC"

{
    # The sets lib/jxl.cmake compiles with boxes and JPEG transcoding on, which the flag set below enables.
    for set in ENC DEC DEC_BOX DEC_JPEG CMS; do
        awk "/set\(JPEGXL_INTERNAL_${set}_SOURCES/{f=1;next} f&&/^\)/{f=0} f" lib/jxl_lists.cmake | sed 's/^ *//' | grep '\.cc$' | sed 's#^#lib/#'
    done
    for name in abort aligned_allocator nanobenchmark per_target print targets timer; do
        echo "third_party/highway/hwy/$name.cc"
    done
    echo lib/threads/thread_parallel_runner.cc
    echo lib/threads/thread_parallel_runner_internal.cc
    echo third_party/skcms/skcms.cc
    echo third_party/skcms/src/skcms_TransformBaseline.cc
    ls third_party/brotli/c/common/*.c third_party/brotli/c/enc/*.c third_party/brotli/c/dec/*.c
} | sort -u > "$LIST"

# The flag set Package.swift gives these targets, so the header closure matches what the build includes.
DEFS="-DNDEBUG -DJXL_INTERNAL_LIBRARY_BUILD -DJXL_STATIC_DEFINE -DJXL_CMS_STATIC_DEFINE -DJXL_THREADS_INTERNAL_LIBRARY_BUILD -DJXL_THREADS_STATIC_DEFINE -DHWY_STATIC_DEFINE -DJPEGXL_ENABLE_BOXES=1 -DJPEGXL_ENABLE_SKCMS=1 -DJPEGXL_ENABLE_TRANSCODE_JPEG=1 -DSKCMS_DISABLE_HSW -DSKCMS_DISABLE_SKX -DFJXL_ENABLE_AVX512=0"
INCS="-I$GEN -I. -Ilib/include -Ithird_party/highway -Ithird_party/brotli/c/include -Ithird_party/skcms"
export DEFS INCS

{
    cat "$LIST"
    xargs -P 8 -n 1 sh -c 'case "$0" in *.c) xcrun clang -MM $DEFS $INCS "$0" ;; *) xcrun clang++ -std=c++17 -MM $DEFS $INCS "$0" ;; esac' < "$LIST" \
        | tr ' \\' '\n\n' | grep -E '\.(h|inc)$' | grep -v '^/' | sed 's#^\./##'
} | sort -u | while read -r file; do
    case "$file" in
        third_party/brotli/*) dest="$BROTLI/${file#third_party/brotli/}" ;;
        *) dest="$JXL/$file" ;;
    esac
    mkdir -p "$(dirname "$dest")"
    cp "$file" "$dest"
done

cp "$GEN"/jxl/*.h "$JXL/lib/include/jxl/"

# Only the C encoder and thread runner APIs: the umbrella directory would also take the C++-only headers.
cat > "$JXL/lib/include/module.modulemap" <<'EOF'
module libjxl {
    header "jxl/encode.h"
    header "jxl/thread_parallel_runner.h"
    export *
}
EOF

cp LICENSE "$ROOT/Licenses/libjxl-LICENSE.txt"
cp PATENTS "$ROOT/Licenses/libjxl-PATENTS.txt"
cp third_party/highway/LICENSE-BSD3 "$ROOT/Licenses/highway-LICENSE-BSD3.txt"
cp third_party/brotli/LICENSE "$ROOT/Licenses/brotli-LICENSE.txt"
cp third_party/skcms/LICENSE "$ROOT/Licenses/skcms-LICENSE.txt"

{
    echo "libjxl $(git describe --tags)"
    for module in highway brotli skcms; do
        echo "$module $(git -C "third_party/$module" rev-parse HEAD)"
    done
} > "$ROOT/upstream-versions.txt"

rm -rf "$LIST" "$GEN"
echo "libjxl: $(find "$JXL" -name '*.cc' | wc -l) sources, $(find "$JXL" -name '*.h' | wc -l) headers"
echo "libbrotli: $(find "$BROTLI" -name '*.c' | wc -l) sources, $(find "$BROTLI" -name '*.h' | wc -l) headers"
cat "$ROOT/upstream-versions.txt"
