// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 规则 IR：检测器 / 算子 / 策略 / 规则集的静态结构，以及按 id 查找。

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
