#!/usr/bin/env bash
# build.sh — 构建四端产物
# 用法：bash scripts/build.sh [--release]
# 产物目录：dist/
set -euo pipefail
cd "$(dirname "$0")/.."

# Windows: 自动导入 MSVC 环境（native 构建需要 cl.exe）。
case "${OSTYPE:-}" in
  msys*|cygwin*)
    if [ -f scripts/msvc-env.sh ]; then
      MSVC_ENV_QUIET=1 source scripts/msvc-env.sh || true
    fi
    ;;
esac

PROFILE="debug"
EXTRA=""
if [ "${1:-}" = "--release" ]; then PROFILE="release"; EXTRA="--release"; fi
MOON="${MOON:-moon}"
mkdir -p dist

echo "== js (esm) =="
"$MOON" build --target js $EXTRA
JS="_build/js/$PROFILE/build/js/js.js"
if [ -f "$JS" ]; then
  cp "$JS" dist/veil.js
  echo "  -> dist/veil.js (ESM)"
fi

echo "== wasm =="
"$MOON" build --target wasm $EXTRA
echo "  -> _build/wasm/$PROFILE/build/*/*.wasm"

echo "== wasm-gc =="
"$MOON" build --target wasm-gc $EXTRA
echo "  -> _build/wasm-gc/$PROFILE/build/*/*.wasm"

echo "== native (需 MSVC / clang) =="
NATIVE_DIR="_build/native/$PROFILE/build/cli"
if "$MOON" build --target native $EXTRA; then
  if [ -f "$NATIVE_DIR/cli.exe" ]; then
    cp "$NATIVE_DIR/cli.exe" dist/veil.exe
    echo "  -> dist/veil.exe"
  elif [ -f "$NATIVE_DIR/cli" ]; then
    cp "$NATIVE_DIR/cli" dist/veil
    echo "  -> dist/veil"
  else
    echo "  -> native build ok (binary not found under $NATIVE_DIR)"
  fi
else
  echo "  -> native build skipped (MSVC/clang unavailable)"
fi

echo "== done =="
ls -la dist
