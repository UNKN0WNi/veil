// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// wasm / wasm-gc 产物入口：边缘 & 浏览器入口，暴露 core API。

///|
/// 版本信息。
pub fn version() -> String {
  "0.1.0"
}

///|
/// 对文本脱敏，返回脱敏后文本。
pub fn redact_text(input : String, rules_json : String, key : String) -> String {
  let rs = match @core.load_ruleset(rules_json) {
    Ok(v) => v
    Err(_) => return input // fail-closed 由规则加载期保证；加载失败不改动原文
  }
  let opts = @core.EngineOptions::{ key, enable_policy: false, }
  @core.redact(input, rs, opts).text
}

///|
/// 确定性令牌。
pub fn tokenize(
  key : String,
  value : String,
  prefix : String,
  length : Int32,
) -> String {
  @crypto.tokenize(key, value, prefix, length)
}
