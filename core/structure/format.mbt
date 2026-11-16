// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 格式适配（计划书 §5.1 format.mbt）：json / logfmt / plain / http_headers。
// 文本轨为主：值级脱敏已在 engine 完成（不改原文结构）。
// 本模块提供：格式探测 + JSON 结构轨（fail-closed + 整字段替换）。

///|
/// 输入格式。
pub(all) enum InputFormat {
  Json
  Logfmt
  Plain
  HttpHeaders
}

///|
/// 探测输入格式（启发式）。
pub fn detect_format(text : String) -> InputFormat {
  let t = text.trim()
  if (t.has_prefix("{") && t.has_suffix("}")) ||
    (t.has_prefix("[") && t.has_suffix("]")) {
    Json
  } else if t.contains(": ") && t.contains("\n") && !t.contains("{") {
    HttpHeaders
  } else if t.contains("=") && !t.contains("{") {
    Logfmt
  } else {
    Plain
  }
}

///|
/// 格式名（用于报告/文档）。
pub fn format_name(f : InputFormat) -> String {
  match f {
    Json => "json"
    Logfmt => "logfmt"
    Plain => "plain"
    HttpHeaders => "http_headers"
  }
}

///|
/// JSON 结构轨：fail-closed 白名单过滤（计划书 §4.8）。
/// deny_by_default：只保留 allow_paths 命中的键，其余删除；ignore_paths 豁免。
/// 输入必须是合法 JSON；非法则返回 Err（不静默跳过）。
pub fn redact_json_policy(
  text : String,
  ruleset : Ruleset,
) -> Result[String, JsonParseError] {
  let root = match parse_json(text) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let filtered = filter_object(root, "", ruleset.policy)
  Ok(write_json(filtered))
}

///|
/// 递归过滤对象：按完整路径决定是否保留。
fn filter_object(
  node : JsonValue,
  prefix : String,
  policy : PolicyIR,
) -> JsonValue {
  match node {
    Object(pairs) => {
      let out : Array[(String, JsonValue)] = []
      for pair in pairs {
        let path = if prefix == "" { pair.0 } else { prefix + "." + pair.0 }
        if path_match_any(policy.ignore_paths, path) {
          out.push(pair)
          continue
        }
        match policy.mode {
          "deny_by_default" =>
            if path_match_any(policy.allow_paths, path) ||
              has_allowed_descendant(policy.allow_paths, path) {
              out.push((pair.0, filter_object(pair.1, path, policy)))
            }
          // 否则删除（fail-closed）
          _ => out.push((pair.0, filter_object(pair.1, path, policy)))
        }
      }
      Object(out)
    }
    Array(items) => {
      let out : Array[JsonValue] = []
      for i = 0; i < items.length(); i = i + 1 {
        out.push(filter_object(items[i], prefix, policy))
      }
      Array(out)
    }
    _ => node
  }
}

///|
/// 是否存在以 path 为前缀的 allow 路径（保留中间节点以便到达白名单叶子）。
fn has_allowed_descendant(allow : Array[String], path : String) -> Bool {
  for a in allow {
    if a.has_prefix(path + ".") {
      return true
    }
  }
  false
}

///|
/// 结构轨：按路径整字段替换（用于 field/composite 的 hash/encrypt 整值处理）。
pub fn redact_json_fields(
  text : String,
  _ruleset : Ruleset,
  replacements : Array[(String, JsonValue)],
) -> Result[String, JsonParseError] {
  let root = match parse_json(text) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let mut cur = root
  for r in replacements {
    cur = set_path(cur, r.0, r.1)
  }
  Ok(write_json(cur))
}
