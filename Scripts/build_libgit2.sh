#!/bin/bash
# 构建 libgit2 静态库（macOS / iOS 设备 / iOS 模拟器），含完整 SSH 支持（OpenSSL 后端）
#
# 依赖源码（位于 External/）：
#   - libgit2  v1.8.4   https://github.com/libgit2/libgit2
#   - libssh2  v1.11.1  https://github.com/libssh2/libssh2
#   - OpenSSL  v3.4.1   https://github.com/openssl/openssl （libssh2 的加密后端，支持 ed25519 等全部算法）
#
# 产物（仅 build/lib 与 build/include 纳入版本控制）:
#   External/libgit2/build/lib/libgit2.xcframework   (macOS / iOS 真机 / iOS 模拟器，
#                                                     已合并 libssh2 + libssl/libcrypto 对象)
#   External/libgit2/build/include/                  (git2 头文件)
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT_DIR/External/libgit2"
OSSL_SRC="$ROOT_DIR/External/openssl"
SSH2_SRC="$ROOT_DIR/External/libssh2"
BUILD_DIR="$SRC_DIR/build"
OUT_LIB_DIR="$BUILD_DIR/lib"
OUT_INC_DIR="$BUILD_DIR/include"

CMAKE_OPTS="-DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_CLI=OFF -DUSE_THREADS=ON -DUSE_HTTPS=SecureTransport"

osx_flags() {
    local flags="-DCMAKE_OSX_ARCHITECTURES=$1 -DCMAKE_OSX_DEPLOYMENT_TARGET=$3"
    if [ -n "$2" ]; then
        flags="$flags -DCMAKE_OSX_SYSROOT=$2"
    fi
    echo "$flags"
}

# 编译一个 OpenSSL 切片（out-of-source 拷贝构建）
build_openssl_slice() {
    # $1 Configure 目标 $2 切片名
    local target="$1" name="$2"
    echo "==> 构建 OpenSSL 切片: $name ($target)"
    local dst="$BUILD_DIR/openssl-$name"
    rm -rf "$dst"
    cp -R "$OSSL_SRC" "$dst"
    (cd "$dst" && \
        ./Configure "$target" no-shared no-tests --prefix="$dst/out" && \
        make -j 8 build_libs)
}

# 平台级 OpenSSL 构建：多架构 lipo 合并到 install-$1-openssl
build_openssl() {
    # $1 out 名 $2 切片列表（空格分隔：目标:名称）
    local out="$1"; shift
    local slices=("$@")
    local first=""
    for item in "${slices[@]}"; do
        local target="${item%%:*}" name="${item##*:}"
        build_openssl_slice "$target" "$name"
        if [ -z "$first" ]; then first="$name"; fi
    done

    local prefix="$BUILD_DIR/install-$out-openssl"
    mkdir -p "$prefix/lib" "$prefix/include"
    # 头文件取第一个切片（各切片头文件一致）
    cp -R "$BUILD_DIR/openssl-$first/include/openssl" "$prefix/include/"

    for lib in libssl libcrypto; do
        local inputs=()
        for item in "${slices[@]}"; do
            inputs+=("$BUILD_DIR/openssl-${item##*:}/$lib.a")
        done
        if [ ${#inputs[@]} -eq 1 ]; then
            cp "${inputs[0]}" "$prefix/lib/$lib.a"
        else
            lipo -create "${inputs[@]}" -o "$prefix/lib/$lib.a"
        fi
    done
}

build_deps() {
    local out="$1"; shift
    # 剩余参数为该平台的 OpenSSL 切片列表
    build_openssl "$out" "$@"

    echo "==> 构建 $out 依赖: libssh2"
    local flags="$(osx_flags "$ARCHS" "$SYSROOT" "$DEPLOYMENT")"
    cmake -S "$SSH2_SRC" -B "$BUILD_DIR/$out-libssh2" \
        $flags \
        -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/install-$out-libssh2" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON \
        -DBUILD_EXAMPLES=OFF -DBUILD_TESTING=OFF \
        -DCRYPTO_BACKEND=OpenSSL \
        -DOPENSSL_ROOT_DIR="$BUILD_DIR/install-$out-openssl"
    cmake --build "$BUILD_DIR/$out-libssh2" --config Release -j 8
    cmake --install "$BUILD_DIR/$out-libssh2" --config Release
}

build() {
    # $1 archs $2 out $3 sysroot $4 deployment；其余为该平台的 OpenSSL 切片列表
    local archs="$1" out="$2" sysroot="$3" deployment="$4"; shift 4
    ARCHS="$archs" SYSROOT="$sysroot" DEPLOYMENT="$deployment"
    echo "==> 构建 $out (archs: $archs, sysroot: ${sysroot:-macosx}, deployment: $deployment)"

    build_deps "$out" "$@"

    cmake -S "$SRC_DIR" -B "$BUILD_DIR/$out" \
        $(osx_flags "$archs" "$sysroot" "$deployment") \
        -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/install-$out" \
        -DUSE_SSH=ON \
        -DLIBSSH2_INCLUDE_DIR="$BUILD_DIR/install-$out-libssh2/include" \
        -DLIBSSH2_LIBRARY="$BUILD_DIR/install-$out-libssh2/lib/libssh2.a" \
        $CMAKE_OPTS
    cmake --build "$BUILD_DIR/$out" --config Release -j 8
    cmake --install "$BUILD_DIR/$out" --config Release

    # 把 libssh2 / OpenSSL 对象合并进 libgit2.a，对外保持单库依赖
    local merged="$BUILD_DIR/install-$out/lib/libgit2-merged.a"
    libtool -static -o "$merged" \
        "$BUILD_DIR/install-$out/lib/libgit2.a" \
        "$BUILD_DIR/install-$out-libssh2/lib/libssh2.a" \
        "$BUILD_DIR/install-$out-openssl/lib/libssl.a" \
        "$BUILD_DIR/install-$out-openssl/lib/libcrypto.a"
}

# 已构建且产物齐全则跳过（供 pod install / lint 快速通过）
if [ -d "$OUT_LIB_DIR/libgit2.xcframework" ] && [ -f "$OUT_INC_DIR/git2.h" ]; then
    echo "libgit2 静态库已存在，跳过构建。"
    exit 0
fi

rm -rf "$BUILD_DIR"
mkdir -p "$OUT_LIB_DIR" "$OUT_INC_DIR"

# macOS (arm64 + x86_64, 部署目标 12.0)
build "arm64;x86_64" "macos" "" "12.0" \
    "darwin64-arm64-cc:macos-arm64" "darwin64-x86_64-cc:macos-x86_64"

# iOS 真机 (arm64, 部署目标 15.0)
build "arm64" "iphoneos" "iphoneos" "15.0" \
    "ios64-xcrun:iphoneos-arm64"

# iOS 模拟器 (arm64 + x86_64, 部署目标 15.0)
build "arm64;x86_64" "iphonesimulator" "iphonesimulator" "15.0" \
    "iossimulator-arm64-xcrun:simulator-arm64" "iossimulator-x86_64-xcrun:simulator-x86_64"

# 打包为 XCFramework（真机/模拟器 arm64 架构重名，无法用 lipo 合并 fat 库）
xcodebuild -create-xcframework \
    -library "$BUILD_DIR/install-macos/lib/libgit2-merged.a" -headers "$BUILD_DIR/install-macos/include" \
    -library "$BUILD_DIR/install-iphoneos/lib/libgit2-merged.a" -headers "$BUILD_DIR/install-iphoneos/include" \
    -library "$BUILD_DIR/install-iphonesimulator/lib/libgit2-merged.a" -headers "$BUILD_DIR/install-iphonesimulator/include" \
    -output "$OUT_LIB_DIR/libgit2.xcframework"

# 头文件（使用 macOS 构建产出的即可，均为 Apple 平台通用）
cp -R "$BUILD_DIR/install-macos/include/." "$OUT_INC_DIR/"

echo "==> 构建完成:"
ls "$OUT_LIB_DIR/libgit2.xcframework/"
lipo -info "$OUT_LIB_DIR/libgit2.xcframework/ios-arm64/libgit2-merged.a"
lipo -info "$OUT_LIB_DIR/libgit2.xcframework/ios-arm64_x86_64-simulator/libgit2-merged.a"
