#!/usr/bin/env bash
# consistency.sh — 跨后端逐字节一致性验证（计划书 §7.2 / S4）
# 用法：bash scripts/consistency.sh [targets...]
#   默认 targets = wasm wasm-gc js native
# 原理：同一套 spec/test-cases/cases.json，在每个后端编译产物上运行（若可运行），
#       比对 expected_output 逐字节一致。
#   native 需要 cl.exe / clang-cl.exe 在 PATH 中；否则自动跳过。
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

MOON="${MOON:-moon}"
TARGETS=("$@")
if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=(wasm wasm-gc js native)
fi

echo "== veil consistency check =="
for t in "${TARGETS[@]}"; do
  if [ "$t" = "native" ] && ! command -v cl >/dev/null 2>&1 && ! command -v clang-cl >/dev/null 2>&1; then
    echo "--- target: native ---"
    echo "SKIP: cl.exe / clang-cl.exe not in PATH (run from a Developer Command Prompt or call vcvars64.bat)"
    continue
  fi
  echo "--- target: $t ---"
  "$MOON" check --target "$t" >/dev/null 2>&1 || { echo "FAIL: moon check $t"; exit 1; }
  "$MOON" test --target "$t" 2>&1 | grep -E "Total tests|FAILED" || true
  "$MOON" build --target "$t" >/dev/null 2>&1 || { echo "FAIL: moon build $t"; exit 1; }
done

# Golden cases via the JS ESM product (runnable in Node).
echo "--- golden cases (JS ESM product) ---"
"$MOON" build --target js >/dev/null 2>&1
node --input-type=module - <<'NODE'
import * as veil from './_build/js/debug/build/js/js.js';
import fs from 'node:fs';
const cases = JSON.parse(fs.readFileSync('spec/test-cases/cases.json', 'utf8')).cases;
let failed = 0;
for (const c of cases) {
  const rules = JSON.stringify(c.ruleset);
  const status = veil.load_ruleset_status(rules);
  if (status !== '') { console.log(`FAIL ${c.id}: ruleset error ${status}`); failed++; continue; }
  const res = JSON.parse(veil.redact_text(c.input, rules, c.key || ''));
  if (res.text !== c.expected_output) {
    console.log(`FAIL ${c.id}: got ${JSON.stringify(res.text)} expected ${JSON.stringify(c.expected_output)}`);
    failed++;
  } else {
    console.log(`OK   ${c.id}`);
  }
}
if (failed > 0) { console.error(`${failed} golden case(s) failed`); process.exit(1); }
console.log('All golden cases byte-identical.');
NODE

# Golden cases via the native CLI (same cases, subprocess boundary).
echo "--- golden cases (native CLI) ---"
NATIVE_BIN=""
for p in _build/native/debug/build/cli/cli.exe _build/native/debug/build/cli/cli; do
  if [ -f "$p" ]; then NATIVE_BIN="$p"; break; fi
done
if [ -z "$NATIVE_BIN" ]; then
  echo "SKIP: native CLI binary not found"
else
  VEIL_NATIVE_BIN="$NATIVE_BIN" node --input-type=module - <<'NODE'
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const bin = process.env.VEIL_NATIVE_BIN;
const cases = JSON.parse(fs.readFileSync('spec/test-cases/cases.json', 'utf8')).cases;
let failed = 0;
for (const c of cases) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'veil-case-'));
  try {
    const rulesFile = path.join(dir, 'rules.json');
    fs.writeFileSync(rulesFile, JSON.stringify(c.ruleset));
    const out = execFileSync(
      bin,
      ['--text', c.input, '--rules', rulesFile, '--json'],
      { encoding: 'utf8', env: { ...process.env, VEIL_KEY: c.key || '' } },
    );
    const res = JSON.parse(out.trim());
    const expectedCount = (c.expected_matches || []).length;
    if (res.text !== c.expected_output || res.count !== expectedCount) {
      console.log(`FAIL ${c.id}: got ${JSON.stringify(res)} expected ${JSON.stringify({ text: c.expected_output, count: expectedCount })}`);
      failed++;
    } else {
      console.log(`OK   ${c.id}`);
    }
  } catch (e) {
    console.log(`FAIL ${c.id}: native CLI error: ${e.message}`);
    failed++;
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}
if (failed > 0) { console.error(`${failed} native golden case(s) failed`); process.exit(1); }
console.log('All native golden cases byte-identical.');
NODE
fi

# HMAC golden vector must be cross-language standard (UTF-8).
echo "--- HMAC golden vector ---"
node --input-type=module - <<'NODE'
import * as veil from './_build/js/debug/build/js/js.js';
const got = veil.hmac_sha256_hex('secret-key', 'hello@example.com');
const exp = '928bc0a4262ca7746556831aee52ee3edfb53b2efd95c57a8f4d1efd051f6d80';
if (got !== exp) { console.error(`FAIL hmac: ${got}`); process.exit(1); }
console.log('OK   hmac ' + got);
NODE

echo "== consistency check passed =="
