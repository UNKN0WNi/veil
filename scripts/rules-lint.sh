#!/usr/bin/env bash
# rules-lint.sh — 内置规则集 lint
# 检查：JSON 合法 / 必填 description / id snake_case / 禁用正则语法。
set -euo pipefail
cd "$(dirname "$0")/.."

RULE_FILES=(rules/*.json)
FAILED=0

for f in "${RULE_FILES[@]}"; do
  echo "--- lint $f ---"
  # 1) JSON 合法
  if ! python3 -c "import json,sys; json.load(open('$f'))" 2>/dev/null; then
    echo "FAIL: invalid JSON: $f"; FAILED=1; continue
  fi
  # 2) 必填字段 + id snake_case + 正则禁用语法
  python3 - "$f" <<'PY' || FAILED=1
import json, sys, re
f = sys.argv[1]
d = json.load(open(f))
errs = []
for det in d.get('detectors', []):
    did = det.get('id', '')
    if not did: errs.append('detector missing id')
    if not re.match(r'^[a-z][a-z0-9_]*$', did): errs.append(f'id not snake_case: {did}')
    if not det.get('description'): errs.append(f'missing description: {did}')
    pat = det.get('pattern', '')
    # lexmatch 禁用语法：\d \w \s \b 与字符类末尾裸 -
    for esc in ['\\d', '\\w', '\\s', '\\b']:
        if esc in pat: errs.append(f'forbidden regex escape {esc} in {did}')
    if re.search(r'\[[^\]]*[^\\]-]', pat): errs.append(f'bare dash at char-class end in {did}')
if errs:
    for e in errs: print('FAIL:', e)
    sys.exit(1)
print('OK:', f, len(d.get('detectors', [])), 'detectors')
PY
done

if [ "$FAILED" -ne 0 ]; then
  echo "rules-lint FAILED"; exit 1
fi
echo "rules-lint passed"
