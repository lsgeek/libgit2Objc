#!/bin/bash
# 构建 libgit2 静态库（macOS / iOS 设备 / iOS 模拟器）
# 产物:
#   External/libgit2/build/lib/libgit2.xcframework   (macOS / iOS 真机 / iOS 模拟器)
#   External/libgit2/build/include/                  (git2 头文件)
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT_DIR/External/libgit2"
BUILD_DIR="$SRC_DIR/build"
OUT_LIB_DIR="$BUILD_DIR/lib"
OUT_INC_DIR="$BUILD_DIR/include"

CMAKE_OPTS="-DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_CLI=OFF -DUSE_THREADS=ON -DUSE_HTTPS=SecureTransport"

build() {
    # $1 architectures (分号分隔)
    # $2 输出目录名
    # $3 SDK sysroot（可选，iOS 必须指定才能找到框架）
    # $4 部署目标（可选）
    # 注意: 不能设 CMAKE_SYSTEM_NAME=iOS，libgit2 的框架检测
    # (MATCHES "Darwin") 会因此跳过；用 sysroot 指定 iOS SDK 即可
    local archs="$1" out="$2" sysroot="${3:-}" deployment="${4:-}"
    echo "==> 构建 $out (archs: $archs, sysroot: ${sysroot:-macosx}, deployment: ${deployment:-默认})"
    local extra=""
    if [ -n "$sysroot" ]; then
        extra="$extra -DCMAKE_OSX_SYSROOT=$sysroot"
    fi
    if [ -n "$deployment" ]; then
        extra="$extra -DCMAKE_OSX_DEPLOYMENT_TARGET=$deployment"
    fi
    cmake -S "$SRC_DIR" -B "$BUILD_DIR/$out" \
        -DCMAKE_OSX_ARCHITECTURES="$archs" \
        -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/install-$out" \
        $extra $CMAKE_OPTS
    cmake --build "$BUILD_DIR/$out" --config Release -j 8
    cmake --install "$BUILD_DIR/$out" --config Release
}

# 已构建且产物齐全则跳过（供 pod install / lint 快速通过）
if [ -d "$OUT_LIB_DIR/libgit2.xcframework" ] && [ -f "$OUT_INC_DIR/git2.h" ]; then
    echo "libgit2 静态库已存在，跳过构建。"
    exit 0
fi

rm -rf "$BUILD_DIR"
mkdir -p "$OUT_LIB_DIR" "$OUT_INC_DIR"

# macOS (arm64 + x86_64, 部署目标 12.0)
build "arm64;x86_64" "macos" "" "12.0"

# iOS 真机 (arm64, 部署目标 15.0)
build "arm64" "iphoneos" "iphoneos" "15.0"

# iOS 模拟器 (arm64 + x86_64, 部署目标 15.0)
build "arm64;x86_64" "iphonesimulator" "iphonesimulator" "15.0"

# 打包为 XCFramework（真机/模拟器 arm64 架构重名，无法用 lipo 合并 fat 库）
xcodebuild -create-xcframework \
    -library "$BUILD_DIR/install-macos/lib/libgit2.a" -headers "$BUILD_DIR/install-macos/include" \
    -library "$BUILD_DIR/install-iphoneos/lib/libgit2.a" -headers "$BUILD_DIR/install-iphoneos/include" \
    -library "$BUILD_DIR/install-iphonesimulator/lib/libgit2.a" -headers "$BUILD_DIR/install-iphonesimulator/include" \
    -output "$OUT_LIB_DIR/libgit2.xcframework"

# 头文件（使用 macOS 构建产出的即可，均为 Apple 平台通用）
cp -R "$BUILD_DIR/install-macos/include/." "$OUT_INC_DIR/"

echo "==> 构建完成:"
ls "$OUT_LIB_DIR/libgit2.xcframework/"
lipo -info "$OUT_LIB_DIR/libgit2.xcframework/ios-arm64/libgit2.a"
lipo -info "$OUT_LIB_DIR/libgit2.xcframework/ios-arm64_x86_64-simulator/libgit2.a"
