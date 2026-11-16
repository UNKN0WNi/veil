// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// JS (esm/npm) 产物入口：暴露 core 的公开 API 给 Node / 浏览器 / 扩展。
// 使用：见 README「JavaScript / npm」一节。

///|
/// 版本信息。
pub fn version() -> String {
  "0.1.0"
}

///|
/// 从规则 JSON 文本加载规则集；返回错误描述或空字符串（成功）。
pub fn load_ruleset_status(rules_json : String) -> String {
  match @core.load_ruleset(rules_json) {
    Ok(_) => ""
    Err(e) => {
      let mut msg = ""
      for err in e.errors {
        msg += err + "; "
      }
      msg
    }
  }
}

///|
/// 对文本脱敏（规则 JSON + 密钥）。返回结果 JSON：{"text":...,"count":...}。
pub fn redact_text(input : String, rules_json : String, key : String) -> String {
  let rs = match @core.load_ruleset(rules_json) {
    Ok(v) => v
    Err(_) => return "{\"text\":\"\",\"count\":-1}"
  }
  let opts = @core.EngineOptions::{ key, enable_policy: false, }
  let result = @core.redact(input, rs, opts)
  let escaped = escape_json_string(result.text)
  "{\"text\":\"" +
  escaped +
  "\",\"count\":" +
  result.report.matched_count.to_string() +
  "}"
}

///|
/// 确定性令牌（HMAC-SHA256，UTF-8，跨语言标准向量）。
pub fn tokenize(
  key : String,
  value : String,
  prefix : String,
  length : Int32,
) -> String {
  @crypto.tokenize(key, value, prefix, length)
}

///|
/// HMAC-SHA256 hex。
pub fn hmac_sha256_hex(key : String, message : String) -> String {
  @crypto.hmac_sha256_hex(key, message)
}

///|
/// JSON 字符串转义（最小实现）。
fn escape_json_string(s : String) -> String {
  let mut out = ""
  for c in s.to_array() {
    if c == '"' {
      out += "\\\""
    } else if c == '\\' {
      out += "\\\\"
    } else if c.to_int() == 10 {
      out += "\\n"
    } else if c.to_int() == 13 {
      out += "\\r"
    } else if c.to_int() == 9 {
      out += "\\t"
    } else {
      out += "\{c}"
    }
  }
  out
}
