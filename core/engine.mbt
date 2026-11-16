// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 执行引擎（计划书 §5.4）：
// ① 值级扫描（pattern / dictionary / composite）→ ② 上下文打分
// → ③ 校验和过滤 → ④ 重叠消解 → ⑤ 执行算子 → ⑥ 文本轨区间替换
// + 审计报告（绝不含原文）。

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
  let detections = detect_all(text, ruleset, ruleset.min_score)
  let resolved = resolve_overlaps(detections)
  let output = apply_replacements(text, resolved, ruleset, options.key)
  let report = build_report(ruleset, resolved)
  RedactResult::{ text: output, report, }
}

///|
/// 扫描所有检测器，返回候选命中。
fn detect_all(
  text : String,
  ruleset : Ruleset,
  min_score : Double,
) -> Array[Detected] {
  let out : Array[Detected] = []
  for i = 0; i < ruleset.detections.length(); i = i + 1 {
    let d = ruleset.detections[i]
    match d.kind {
      Pattern => detect_pattern(text, d, i, min_score, out)
      Dictionary => detect_dictionary(text, d, i, min_score, out)
      Checksum => detect_checksum(text, d, i, min_score, out)
      Composite => detect_composite(text, d, i, ruleset, min_score, out)
      Field => () // 字段级在结构轨处理（本函数负责值级）
    }
  }
  out
}

///|
/// 正则检测器：用 lexmatch 正则扫描（@string.Regex）。
fn detect_pattern(
  text : String,
  d : DetectorIR,
  order : Int32,
  min_score : Double,
  out : Array[Detected],
) -> Unit {
  if d.pattern == "" {
    return
  }
  let re = @string.Regex(d.pattern) catch { _ => return }
  for m in re.find(text) {
    let before = m.before().to_owned()
    let content = m.content().to_owned()
    let start = before.length()
    let end = start + content.length()
    add_detection(text, content, start, end, d, order, min_score, out)
  }
}

///|
/// 词典检测器：子串匹配（可选大小写不敏感）。
fn detect_dictionary(
  text : String,
  d : DetectorIR,
  order : Int32,
  min_score : Double,
  out : Array[Detected],
) -> Unit {
  let haystack = if d.case_sensitive { text } else { text.to_lower() }
  let chars = if d.case_sensitive {
    text.to_array()
  } else {
    text.to_lower().to_array()
  }
  for term in d.terms {
    let needle = if d.case_sensitive { term } else { term.to_lower() }
    if needle.length() == 0 {
      continue
    }
    let mut from = 0
    while from <= chars.length() - needle.length() {
      let idx = find_substring(chars, needle.to_array(), from)
      if idx < 0 {
        break
      }
      // 命中原文（用原始 text 的对应偏移）
      let end = idx + needle.length()
      let original = text[:][idx:end].to_owned()
      add_detection(text, original, idx, end, d, order, min_score, out)
      from = idx + needle.length()
    }
  }
}

///|
/// 子串查找（字符数组，返回起始下标，-1 表示未找到）。
fn find_substring(
  hay : Array[Char],
  needle : Array[Char],
  from : Int32,
) -> Int32 {
  if needle.length() == 0 || from > hay.length() - needle.length() {
    return -1
  }
  for i = from; i <= hay.length() - needle.length(); i = i + 1 {
    let mut ok = true
    for j = 0; j < needle.length(); j = j + 1 {
      if hay[i + j] != needle[j] {
        ok = false
        break
      }
    }
    if ok {
      return i
    }
  }
  -1
}

///|
/// 校验和检测器：正则提取候选 + validator 过滤。
fn detect_checksum(
  text : String,
  d : DetectorIR,
  order : Int32,
  min_score : Double,
  out : Array[Detected],
) -> Unit {
  if d.pattern == "" {
    return
  }
  let re = @string.Regex(d.pattern) catch { _ => return }
  for m in re.find(text) {
    let content = m.content().to_owned()
    if !validate(d.validator, content) {
      continue
    }
    let start = m.before().to_owned().length()
    let end = start + content.length()
    add_detection(text, content, start, end, d, order, min_score, out)
  }
}

///|
/// 复合检测器：先按 field 定位，再对字段值跑引用的子检测器。
/// 文本轨近似：在原文中搜索 `"path尾段": "值"` 结构。
fn detect_composite(
  text : String,
  d : DetectorIR,
  order : Int32,
  ruleset : Ruleset,
  min_score : Double,
  out : Array[Detected],
) -> Unit {
  for target in d.targets {
    let leaf = last_segment(target)
    let needle = "\"" + leaf + "\""
    let chars = text.to_array()
    let na = needle.to_array()
    let mut from = 0
    while from <= chars.length() - na.length() {
      let idx = find_substring(chars, na, from)
      if idx < 0 {
        break
      }
      // 找冒号后的字符串值
      let mut p = idx + na.length()
      while p < chars.length() && (chars[p] == ' ' || chars[p] == ':') {
        p += 1
      }
      if p < chars.length() && chars[p] == '"' {
        let vstart = p + 1
        let mut q = vstart
        while q < chars.length() && chars[q] != '"' {
          q += 1
        }
        let value = text[:][vstart:q].to_owned()
        // 跑子检测器（简化：任一子检测器命中即采用）
        for sub_id in d.detectors {
          match find_detector(ruleset, sub_id) {
            Some(sub) if sub.pattern != "" => {
              let re = @string.Regex(sub.pattern) catch { _ => continue }
              if re.execute(value) is Some(_) {
                add_detection(text, value, vstart, q, d, order, min_score, out)
                break
              }
            }
            _ => ()
          }
        }
        from = q + 1
      } else {
        from = idx + na.length()
      }
    }
  }
}

///|
/// 取路径最后一段。
fn last_segment(path : String) -> String {
  let parts = path.split(".").to_array()
  if parts.length() == 0 {
    path
  } else {
    parts[parts.length() - 1].to_owned()
  }
}

///|
/// 构造一条 Detected：上下文打分 + 阈值过滤 + 算子选择。
fn add_detection(
  text : String,
  content : String,
  start : Int32,
  end : Int32,
  d : DetectorIR,
  order : Int32,
  min_score : Double,
  out : Array[Detected],
) -> Unit {
  if content.length() == 0 {
    return
  }
  let delta = context_delta(text, start, end, d.context)
  let score = d.score + delta
  if score < min_score {
    return
  }
  let op_id = if d.action_id != "" { d.action_id } else { "" } // 空 = 用默认
  out.push(Detected::{
    span: Span::{ start, end, },
    detector_id: d.id,
    detector_order: order,
    entity: d.id,
    score,
    matched_by: [d.id],
    operator_id: op_id,
    text: content,
  })
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
