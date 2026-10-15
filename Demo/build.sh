#!/bin/bash
# 编译并运行 macOS 命令行 Demo
set -e
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build-demo"
XCFW="$ROOT_DIR/External/libgit2/build/lib/libgit2.xcframework"
MACOS_LIB="$XCFW/macos-arm64_x86_64/libgit2-merged.a"
HEADERS="$ROOT_DIR/External/libgit2/build/include"

mkdir -p "$BUILD_DIR"

clang -fobjc-arc -O0 -g \
    -I"$ROOT_DIR/libgit2Objc/Classes" \
    -I"$ROOT_DIR/libgit2Objc/Classes/Internal" \
    -I"$HEADERS" \
    -I"$ROOT_DIR/External/libgit2/build/include-openssl" \
    "$ROOT_DIR"/libgit2Objc/Classes/*.m \
    "$ROOT_DIR"/libgit2Objc/Classes/Internal/*.m \
    "$ROOT_DIR/Demo/main.m" \
    "$MACOS_LIB" \
    -framework Foundation -framework Security -framework CoreFoundation \
    -lz -liconv \
    -o "$BUILD_DIR/libgit2ObjcDemo"

echo "编译完成，运行 Demo:"
"$BUILD_DIR/libgit2ObjcDemo"
