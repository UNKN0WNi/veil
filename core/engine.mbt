// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 执行引擎——只做编排，不实现检测与算子：
// ① 值级扫描（@detect）→ ② 重叠消解（@text）
// → ③ 执行算子（@ops）→ ④ 文本轨区间替换 → ⑤ 审计报告（绝不含原文）。

///|
/// 审计记录（不含原值）。
pub(all) struct MatchRecord {
  entity : String
  start : Int32
  end : Int32
  operator : String
  detector : String
}

///|
/// 审计报告。
pub(all) struct RedactionReport {
  mut rules_version : String
  mut matched_count : Int32
  mut by_entity : Array[(String, Int32)]
  mut by_operator : Array[(String, Int32)]
  mut spans : Array[MatchRecord]
}

///|
/// 脱敏结果。
pub(all) struct RedactResult {
  text : String
  report : RedactionReport
}

///|
/// 脱敏选项：密钥与是否启用 fail-closed 结构轨。
pub(all) struct EngineOptions {
  mut key : String
  mut enable_policy : Bool
}

///|
/// 默认引擎选项。
pub fn EngineOptions::default() -> EngineOptions {
  { key: "", enable_policy: false, }
}

///|
/// 主入口：对文本脱敏。key 为 HMAC/令牌密钥（从环境变量注入）。
pub fn redact(
  text : String,
  ruleset : Ruleset,
  options : EngineOptions,
) -> RedactResult {
  let detections = @detect.detect_all(text, ruleset, ruleset.min_score)
  let resolved = resolve_overlaps(detections)
  let output = apply_replacements(text, resolved, ruleset, options.key)
  let report = build_report(ruleset, resolved)
  RedactResult::{ text: output, report, }
}

///|
/// 文本轨区间替换：按 start 升序拼接，命中区间替换为算子输出。
fn apply_replacements(
  text : String,
  detections : Array[Detected],
  ruleset : Ruleset,
  key : String,
) -> String {
  let mut out = ""
  let mut cursor = 0
  for d in detections {
    if d.span.start < cursor {
      continue
    }
    out += text[:][cursor:d.span.start].to_owned()
    let op = select_operator(ruleset, d)
    out += apply_operator(op, d.text, key, ruleset.censor)
    cursor = d.span.end
  }
  out += text[:][cursor:].to_owned()
  out
}

///|
/// 选择算子：detector 级 action_id > 规则集默认。
fn select_operator(ruleset : Ruleset, d : Detected) -> Operator {
  if d.operator_id != "" {
    match find_operator(ruleset, d.operator_id) {
      Some(op) => return op
      None => ()
    }
  }
  match find_operator(ruleset, ruleset.default_action) {
    Some(op) => op
    None => Operator::default()
  }
}

///|
/// 构造审计报告（计数聚合，绝不含原文）。
fn build_report(
  ruleset : Ruleset,
  detections : Array[Detected],
) -> RedactionReport {
  let by_entity : Array[(String, Int32)] = []
  let by_operator : Array[(String, Int32)] = []
  let spans : Array[MatchRecord] = []
  for d in detections {
    let op = select_operator(ruleset, d)
    spans.push(MatchRecord::{
      entity: d.entity,
      start: d.span.start,
      end: d.span.end,
      operator: op.type_,
      detector: d.detector_id,
    })
    bump(by_entity, d.entity)
    bump(by_operator, op.type_)
  }
  RedactionReport::{
    rules_version: ruleset.rules_version,
    matched_count: detections.length(),
    by_entity,
    by_operator,
    spans,
  }
}

///|
/// 计数聚合。
fn bump(counter : Array[(String, Int32)], key : String) -> Unit {
  for i = 0; i < counter.length(); i = i + 1 {
    if counter[i].0 == key {
      counter[i] = (counter[i].0, counter[i].1 + 1)
      return
    }
  }
  counter.push((key, 1))
}
