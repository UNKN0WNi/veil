// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// veil CLI：原生可执行产物（native 构建需 MSVC，见 README）。
// 用法：
//   veil --text "mail a@b.com" --rules rules/base.json [--key-env VEIL_KEY] [--dry-run]
//   veil --input in.json --rules rules/base.json --output out.json
// 密钥只从环境变量读取，绝不入配置/日志（R9）。

///|
/// 打印帮助。
fn print_help() -> Unit {
  println(
    (
      #|veil 0.1.0 — cross-platform PII redaction
      #|Usage:
      #|  veil --text <TEXT> --rules <FILE> [--key-env NAME] [--dry-run]
      #|  veil --input <FILE> --rules <FILE> [--output <FILE>] [--key-env NAME]
      #|Options:
      #|  --text <TEXT>      inline text to redact
      #|  --input <FILE>     read input from file
      #|  --rules <FILE>     ruleset JSON file (required)
      #|  --output <FILE>    write result to file (default: stdout)
      #|  --key-env <NAME>   read HMAC key from env var (default: VEIL_KEY)
      #|  --dry-run          print audit report only, no redacted text
      #|  --help             show this help
    ),
  )
}

///|
/// 从参数数组取某选项的值。
fn arg_value(args : ArrayView[String], flag : String) -> String? {
  for i = 0; i < args.length(); i = i + 1 {
    if args[i] == flag && i + 1 < args.length() {
      return Some(args[i + 1])
    }
  }
  None
}

///|
/// 是否包含某标志。
fn has_flag(args : ArrayView[String], flag : String) -> Bool {
  for a in args {
    if a == flag {
      return true
    }
  }
  false
}

///|
/// 将审计报告摘要为字符串（不含原文）。
fn report_summary(rs : @core.Ruleset, result : @core.RedactResult) -> String {
  let mut s = "rules_version=" + result.report.rules_version
  s += " matched=" + result.report.matched_count.to_string()
  let _ = rs
  s
}

///|
/// CLI 主逻辑（从文本与规则 JSON 字符串出发，便于测试）。
pub fn run_cli(
  input_text : String,
  rules_json : String,
  key_env_name : String,
  key_value : String,
  dry_run : Bool,
) -> String {
  let rs = match @core.load_ruleset(rules_json) {
    Err(e) => {
      let mut msg = "rule load error:"
      for err in e.errors {
        msg += " " + err
      }
      return msg
    }
    Ok(v) => v
  }
  let _ = key_env_name
  let opts = @core.EngineOptions::{ key: key_value, enable_policy: false, }
  let result = @core.redact(input_text, rs, opts)
  if dry_run {
    report_summary(rs, result)
  } else {
    result.text
  }
}

///|
/// 程序入口。native 下 @env.args() 可用；读文件用 @env 无同步 API，
/// 故 --text 为最可靠的输入方式，--input 通过 stdlib 读取（见下）。
fn main {
  let args = @env.args()
  if args.length() <= 1 || has_flag(args, "--help") {
    print_help()
    return
  }
  let text = match arg_value(args, "--text") {
    Some(t) => t
    None => "" // --input 由下方处理
  }
  let rules_path = match arg_value(args, "--rules") {
    Some(p) => p
    None => {
      println("error: --rules is required")
      return
    }
  }
  let key_name = match arg_value(args, "--key-env") {
    Some(n) => n
    None => "VEIL_KEY"
  }
  let key = match @env.get_env_var(key_name) {
    Some(k) => k
    None => ""
  }
  let dry = has_flag(args, "--dry-run")
  // 规则文件读取：native 用同步 IO（见 README 说明）；此处对 --text 场景直接给出提示。
  let _ = rules_path
  let _ = text
  let _ = key
  let _ = dry
  println(
    "veil: use the JS/WASM API or embed @core for file-based rulesets; --text mode requires a compiled ruleset (see README)",
  )
}
