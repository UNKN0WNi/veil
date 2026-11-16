// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 规则集加载：JSON → IR（计划书 §4.10）。
// 读文件 → 解析 → schema/语义校验 → 编译 IR；任一条非法 → 整体失败（不静默跳过）。

///|
/// 检测器类型。
pub(all) enum DetectorKind {
  Pattern
  Dictionary
  Field
  Composite
  Checksum
}

///|
/// 检测器 IR。
pub(all) struct DetectorIR {
  mut id : String
  mut description : String
  mut kind : DetectorKind
  mut pattern : String
  mut terms : Array[String]
  mut targets : Array[String]
  mut detectors : Array[String]
  mut validator : String
  mut context : ContextConf
  mut score : Double
  mut action_id : String
  mut replacement : String
  mut case_sensitive : Bool
}

///|
/// 默认检测器 IR。
fn DetectorIR::default() -> DetectorIR {
  {
    id: "",
    description: "",
    kind: Pattern,
    pattern: "",
    terms: [],
    targets: [],
    detectors: [],
    validator: "",
    context: ContextConf::default(),
    score: 0.5,
    action_id: "",
    replacement: "",
    case_sensitive: false,
  }
}

///|
/// 策略 IR。
pub(all) struct PolicyIR {
  mut mode : String
  mut allow_paths : Array[String]
  mut ignore_paths : Array[String]
}

///|
/// 规则集 IR（编译产物，多次复用）。
pub(all) struct Ruleset {
  mut version : Int32
  mut rules_version : String
  mut censor : String
  mut min_score : Double
  mut default_action : String
  mut detections : Array[DetectorIR]
  mut operators : Array[Operator]
  mut policy : PolicyIR
  mut formats : Array[String]
  mut includes : Array[String]
  mut errors : Array[String]
}

///|
/// 空规则集。
pub fn Ruleset::empty() -> Ruleset {
  {
    version: 1,
    rules_version: "",
    censor: "[REDACTED]",
    min_score: 0.5,
    default_action: "redact",
    detections: [],
    operators: [],
    policy: PolicyIR::{
      mode: "allow_by_default",
      allow_paths: [],
      ignore_paths: [],
    },
    formats: [],
    includes: [],
    errors: [],
  }
}

///|
/// 规则加载错误。
pub(all) struct RuleLoadError {
  errors : Array[String]
}

///|
/// 从严格 JSON 文本加载规则集（含 schema + 语义校验）。
pub fn load_ruleset(json_text : String) -> Result[Ruleset, RuleLoadError] {
  let parsed : Result[@json.Json, String] = try {
    let v = @json.parse(json_text, reject_duplicate_keys=true)
    Ok(v)
  } catch {
    e => Err("json parse error: \{e}")
  }
  match parsed {
    Err(msg) => Err(RuleLoadError::{ errors: [msg], })
    Ok(j) => build_ruleset(j)
  }
}

///|
/// 读取字符串字段（带默认值）。
fn jstr(j : @json.Json, key : String, default : String) -> String {
  match j.value(key) {
    Some(v) =>
      match v.as_string() {
        Some(s) => s
        None => default
      }
    None => default
  }
}

///|
/// 读取数值字段为 Double。
fn jnum(j : @json.Json, key : String, default : Double) -> Double {
  match j.value(key) {
    Some(v) =>
      match v.as_number() {
        Some(n) => n
        None => default
      }
    None => default
  }
}

///|
/// 读取数值字段为 Int。
fn jint(j : @json.Json, key : String, default : Int32) -> Int32 {
  match j.value(key) {
    Some(v) =>
      match v.as_number() {
        Some(n) => n.to_int()
        None => default
      }
    None => default
  }
}

///|
/// 读取布尔字段。
fn jbool(j : @json.Json, key : String, default : Bool) -> Bool {
  match j.value(key) {
    Some(v) =>
      match v.as_bool() {
        Some(b) => b
        None => default
      }
    None => default
  }
}

///|
/// 读取 JSON 字符串数组字段。
fn jarray(j : @json.Json, key : String) -> Array[String] {
  let out : Array[String] = []
  match j.value(key) {
    Some(v) =>
      match v.as_array() {
        Some(arr) =>
          for item in arr {
            if item.as_string() is Some(s) {
              out.push(s)
            }
          }
        None => ()
      }
    None => ()
  }
  out
}

///|
/// 从 JSON 值构造规则集并校验。
pub fn build_ruleset(j : @json.Json) -> Result[Ruleset, RuleLoadError] {
  let rs = Ruleset::empty()
  let errors : Array[String] = []

  if j.value("version").is_none() {
    errors.push("missing required field: version")
  }
  if j.value("rules_version").is_none() {
    errors.push("missing required field: rules_version")
  }
  rs.version = jint(j, "version", 1)
  rs.rules_version = jstr(j, "rules_version", "")

  match j.value("defaults") {
    Some(d) => {
      rs.default_action = jstr(d, "action", "redact")
      rs.censor = jstr(d, "censor", "[REDACTED]")
      rs.min_score = jnum(d, "min_score", 0.5)
    }
    None => ()
  }

  match j.value("detectors") {
    Some(d) =>
      match d.as_array() {
        Some(arr) =>
          for i = 0; i < arr.length(); i = i + 1 {
            rs.detections.push(parse_detector(arr[i], errors))
          }
        None => errors.push("detectors must be an array")
      }
    None => errors.push("missing required field: detectors")
  }

  match j.value("operators") {
    Some(o) =>
      match o.as_array() {
        Some(arr) =>
          for item in arr {
            rs.operators.push(parse_operator(item, errors))
          }
        None => errors.push("operators must be an array")
      }
    None => ()
  }

  match j.value("policy") {
    Some(p) => {
      rs.policy.mode = jstr(p, "mode", "allow_by_default")
      rs.policy.allow_paths = jarray(p, "allow_paths")
      rs.policy.ignore_paths = jarray(p, "ignore_paths")
    }
    None => ()
  }

  // formats / includes 是顶层字符串数组
  match j.value("formats") {
    Some(f) =>
      match f.as_array() {
        Some(arr) => {
          let fmts : Array[String] = []
          for item in arr {
            if item.as_string() is Some(s) {
              fmts.push(s)
            }
          }
          rs.formats = fmts
        }
        None => ()
      }
    None => ()
  }
  match j.value("includes") {
    Some(f) =>
      match f.as_array() {
        Some(arr) => {
          let incs : Array[String] = []
          for item in arr {
            if item.as_string() is Some(s) {
              incs.push(s)
            }
          }
          rs.includes = incs
        }
        None => ()
      }
    None => ()
  }

  // ---- 语义校验 ----
  for i = 0; i < rs.detections.length(); i = i + 1 {
    for k = 0; k < i; k = k + 1 {
      if rs.detections[i].id == rs.detections[k].id {
        errors.push("duplicate detector id: " + rs.detections[i].id)
      }
    }
  }
  let det_ids : Array[String] = []
  for d in rs.detections {
    det_ids.push(d.id)
  }
  for d in rs.detections {
    if d.description == "" {
      errors.push("detector missing description: " + d.id)
    }
    if d.validator != "" && !is_validator(d.validator) {
      errors.push("unknown validator: " + d.validator)
    }
    if d.action_id != "" && !is_operator_type(d.action_id) {
      let mut found = false
      for op in rs.operators {
        if op.id == d.action_id {
          found = true
          break
        }
      }
      if !found {
        errors.push("unknown operator reference: " + d.action_id)
      }
    }
    for sub in d.detectors {
      if !det_ids.contains(sub) {
        errors.push("unknown detector reference: " + sub)
      }
    }
    if d.kind is Pattern || d.kind is Checksum {
      if d.pattern != "" {
        try {
          let _ = @string.Regex(d.pattern)
        } catch {
          _ => errors.push("invalid regex in detector: " + d.id)
        }
      }
    }
  }
  if !is_operator_type(rs.default_action) {
    let mut found = false
    for op in rs.operators {
      if op.id == rs.default_action {
        found = true
        break
      }
    }
    if !found {
      errors.push("unknown default action: " + rs.default_action)
    }
  }

  if errors.length() > 0 {
    Err(RuleLoadError::{ errors, })
  } else {
    Ok(rs)
  }
}

///|
/// 解析单条检测器。
fn parse_detector(item : @json.Json, errors : Array[String]) -> DetectorIR {
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
  match item.value("context") {
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
fn parse_operator(item : @json.Json, errors : Array[String]) -> Operator {
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
  match item.value("keep") {
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
pub fn find_operator(rs : Ruleset, id : String) -> Operator? {
  for op in rs.operators {
    if op.id == id {
      return Some(op)
    }
  }
  None
}

///|
/// 按 id 查找检测器。
pub fn find_detector(rs : Ruleset, id : String) -> DetectorIR? {
  for d in rs.detections {
    if d.id == id {
      return Some(d)
    }
  }
  None
}
