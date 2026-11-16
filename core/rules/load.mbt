// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 规则加载：JSON → IR，schema + 语义校验，任一条非法则整体失败。

///|
pub fn load_ruleset(json_text : String) -> Result[Ruleset, RuleLoadError] {
  let parsed : Result[JsonValue, String] = match parse_json(json_text) {
    Ok(v) => Ok(v)
    Err(e) => Err("json parse error: " + e.message)
  }
  match parsed {
    Err(msg) => Err(RuleLoadError::{ errors: [msg], })
    Ok(j) => build_ruleset(j)
  }
}

///|
pub fn build_ruleset(j : JsonValue) -> Result[Ruleset, RuleLoadError] {
  let rs = Ruleset::empty()
  let errors : Array[String] = []

  if j.get("version") is None {
    errors.push("missing required field: version")
  }
  if j.get("rules_version") is None {
    errors.push("missing required field: rules_version")
  }
  rs.version = jint(j, "version", 1)
  rs.rules_version = jstr(j, "rules_version", "")

  match j.get("defaults") {
    Some(d) => {
      rs.default_action = jstr(d, "action", "redact")
      rs.censor = jstr(d, "censor", "[REDACTED]")
      rs.min_score = jnum(d, "min_score", 0.5)
    }
    None => ()
  }

  match j.get("detectors") {
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

  match j.get("operators") {
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

  match j.get("policy") {
    Some(p) => {
      rs.policy.mode = jstr(p, "mode", "allow_by_default")
      rs.policy.allow_paths = jarray(p, "allow_paths")
      rs.policy.ignore_paths = jarray(p, "ignore_paths")
    }
    None => ()
  }

  // formats / includes 是顶层字符串数组
  match j.get("formats") {
    Some(f) =>
      match f.as_array() {
        Some(arr) => {
          let fmts : Array[String] = []
          for item in arr {
            if item.as_str() is Some(s) {
              fmts.push(s)
            }
          }
          rs.formats = fmts
        }
        None => ()
      }
    None => ()
  }
  match j.get("includes") {
    Some(f) =>
      match f.as_array() {
        Some(arr) => {
          let incs : Array[String] = []
          for item in arr {
            if item.as_str() is Some(s) {
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
