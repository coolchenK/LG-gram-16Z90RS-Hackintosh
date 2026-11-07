#!/bin/bash
# Build the patched VoodooI2CHID binary by hand (no Xcode project needed, only Command Line Tools).
#
#   git clone --recursive https://github.com/VoodooI2C/VoodooI2C.git && cd VoodooI2C
#   git checkout 6be653a && git submodule update --init --recursive
#   (cd "VoodooI2C Satellites/VoodooI2CHID" && git apply /path/to/patches/VoodooI2CHID-lg-gram-ptp-fix.patch)
#   git clone https://github.com/acidanthera/MacKernelSDK.git
#   ./build-voodooi2chid.sh /path/to/VoodooI2C /path/to/MacKernelSDK
#
# The result is a bare binary: copy it over VoodooI2CHID.kext/Contents/MacOS/VoodooI2CHID of the
# VoodooI2C 2.9.1 CI build (commit 6be653a), keeping that kext's Info.plist.
set -e
SRC="${1:?usage: $0 <VoodooI2C checkout> <MacKernelSDK>}"
SDK="${2:?usage: $0 <VoodooI2C checkout> <MacKernelSDK>}"
B="${OUT:-$PWD/vi2cbuild}"
H="$SRC/VoodooI2C Satellites/VoodooI2CHID/VoodooI2CHID"
[ -f "$H/VoodooI2CHIDDevice.cpp" ] || { echo "VoodooI2CHID sources not found under $SRC" >&2; exit 1; }
rm -rf "$B"; mkdir -p "$B/obj"
CF=(-arch x86_64 -std=gnu++14 -Os -g -mkernel -fapple-kext -fno-exceptions -fno-rtti -fno-builtin -fno-common
    -mno-red-zone -nostdinc -DKERNEL -DKERNEL_PRIVATE -DDRIVER_PRIVATE -DAPPLE -DNeXT "-I$SDK/Headers"
    -mmacosx-version-min=10.11 -Wno-everything)
objs=()
while IFS= read -r -d '' f; do
  o="$B/obj/$(basename "$f" .cpp).o"
  xcrun clang++ "${CF[@]}" -c "$f" -o "$o"; objs+=("$o")
done < <(find "$H" -name "*.cpp" ! -name "*.orig" -print0)
cat > "$B/kmod_info.c" <<'EOF'
#include <mach/mach_types.h>
#include <mach/kmod.h>
extern kern_return_t _start(kmod_info_t *, void *);
extern kern_return_t _stop(kmod_info_t *, void *);
__attribute__((visibility("default"))) KMOD_EXPLICIT_DECL(com.alexandred.VoodooI2CHID, "1.0.0d1", _start, _stop)
__attribute__((visibility("hidden"))) kmod_start_func_t *_realmain = 0;
__attribute__((visibility("hidden"))) kmod_stop_func_t *_antimain = 0;
__attribute__((visibility("hidden"))) int _kext_apple_cc = __APPLE_CC__;
EOF
xcrun clang -arch x86_64 -mkernel -nostdinc -DKERNEL "-I$SDK/Headers" -c "$B/kmod_info.c" -o "$B/obj/kmod_info.o"
xcrun ld -arch x86_64 -kext -undefined dynamic_lookup -no_fixup_chains -macos_version_min 10.11 \
  -o "$B/VoodooI2CHID" "${objs[@]}" "$B/obj/kmod_info.o" "$SDK/Library/x86_64/libkmod.a"
echo "built $B/VoodooI2CHID ($(shasum -a 256 "$B/VoodooI2CHID" | cut -c1-16)) from ${#objs[@]} objects"
