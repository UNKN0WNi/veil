// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 单条规则解析：检测器与算子字段 → IR。

///|
fn parse_detector(item : JsonValue, errors : Array[String]) -> DetectorIR {
  let d = DetectorIR::default()
  d.id = jstr(item, "id", "")
  d.description = jstr(item, "description", "")
  if d.id == "" {
    errors.push("detector missing id")
  }
  let typ = jstr(item, "type", "")
  d.kind = match typ {
    "pattern" => Pattern
    "dictionary" => Dictionary
    "field" => Field
    "composite" => Composite
    "checksum" => Checksum
    _ => {
      errors.push("unknown detector type: " + typ)
      Pattern
    }
  }
  d.pattern = jstr(item, "pattern", "")
  let extract = jstr(item, "extract", "")
  if extract != "" {
    d.pattern = extract
  }
  d.terms = jarray(item, "terms")
  d.targets = jarray(item, "targets")
  d.detectors = jarray(item, "detectors")
  d.validator = jstr(item, "validator", "")
  d.score = jnum(item, "score", 0.5)
  d.action_id = jstr(item, "action", "")
  d.replacement = jstr(item, "replacement", "")
  d.case_sensitive = jbool(item, "case_sensitive", false)
  match item.get("context") {
    Some(c) => {
      d.context.words = jarray(c, "words")
      d.context.anti_words = jarray(c, "anti_words")
      d.context.window = jint(c, "window", 24)
      d.context.boost = jnum(c, "boost", 0.0)
      d.context.penalty = jnum(c, "penalty", 0.0)
      d.context.case_sensitive = jbool(c, "case_sensitive", false)
    }
    None => ()
  }
  d
}

///|
/// 解析单条算子。
fn parse_operator(item : JsonValue, errors : Array[String]) -> Operator {
  let op = Operator::default()
  op.id = jstr(item, "id", "")
  op.type_ = jstr(item, "type", "")
  if op.id == "" {
    errors.push("operator missing id")
  }
  if !is_operator_type(op.type_) {
    errors.push("unknown operator type: " + op.type_)
  }
  op.replacement = jstr(item, "replacement", "")
  match item.get("keep") {
    Some(k) => {
      op.keep_prefix = jint(k, "prefix", 0)
      op.keep_suffix = jint(k, "suffix", 0)
    }
    None => ()
  }
  op.fill = jstr(item, "fill", "*")
  op.prefix = jstr(item, "prefix", "")
  op.length = jint(item, "length", 0)
  op.algo = jstr(item, "algo", "hmac_sha256")
  op
}

///|
/// 按 id 查找算子。
