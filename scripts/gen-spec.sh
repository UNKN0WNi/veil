#!/usr/bin/env bash
# gen-spec.sh — 从 rules/ 生成 spec 索引
# 生成 spec/rules-index.json：规则 id → 所属文件 / 类型 / 默认算子，便于其他语言实现消费。
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
import json, glob, os
index = {
  "_comment": "由 scripts/gen-spec.sh 从 rules/*.json 生成，请勿手改；改了规则重跑脚本即可。",
  "version": 1,
  "spec_version": "2026.11.1",
  "rules": [],
}
for f in sorted(glob.glob('rules/*.json')):
    d = json.load(open(f))
    for det in d.get('detectors', []):
        index['rules'].append({
            "id": det.get('id'),
            "type": det.get('type'),
            "source": f.replace(os.sep, '/'),
            "validator": det.get('validator', ''),
            "action": det.get('action', d.get('defaults', {}).get('action', 'redact')),
            "score": det.get('score', d.get('defaults', {}).get('min_score', 0.5)),
        })
with open('spec/rules-index.json', 'w', encoding='utf-8') as out:
    json.dump(index, out, ensure_ascii=False, indent=2)
print(f"generated spec/rules-index.json ({len(index['rules'])} rules)")
PY
