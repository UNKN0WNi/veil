#!/usr/bin/env bash
# build.sh — 构建四端产物
# 用法：bash scripts/build.sh [--release]
# 产物目录：dist/
set -euo pipefail
cd "$(dirname "$0")/.."

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

echo "== native (需 MSVC；不可用则跳过) =="
if "$MOON" build --target native $EXTRA 2>/dev/null; then
  echo "  -> native build ok"
else
  echo "  -> native build skipped (MSVC/toolchain unavailable)"
fi

echo "== done =="
ls -la dist
