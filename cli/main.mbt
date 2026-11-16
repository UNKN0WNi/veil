// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// veil CLI：原生可执行产物。
// 用法：
//   veil --text "mail a@b.com" --rules rules/base.json [--key-env VEIL_KEY] [--dry-run] [--json]
//   veil --input in.json --rules rules/base.json --output out.json
// 密钥只从环境变量读取，绝不入配置/日志（R9）。

///|
/// 打印帮助。
fn print_help() -> Unit {
  println(
    (
      #|veil 0.1.0 — cross-platform PII redaction
      #|Usage:
      #|  veil --text <TEXT> --rules <FILE> [--key-env NAME] [--dry-run] [--json]
      #|  veil --input <FILE> --rules <FILE> [--output <FILE>] [--key-env NAME] [--json]
      #|Options:
      #|  --text <TEXT>      inline text to redact
      #|  --input <FILE>     read input from file
      #|  --rules <FILE>     ruleset JSON file (required)
      #|  --output <FILE>    write result to file (default: stdout)
      #|  --key-env <NAME>   read HMAC key from env var (default: VEIL_KEY)
      #|  --dry-run          print audit report only, no redacted text
      #|  --json             print {"text":...,"count":...} instead of plain text
      #|  --version          print version
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
/// JSON 字符串转义（最小实现，与 js 入口保持一致）。
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

///|
/// 读取文本文件；失败时打印错误并以退出码 2 结束。
fn read_text_file(path : String, label : String) -> String {
  try {
    @fs.read_file_to_string(path)
  } catch {
    _ => {
      eprintln("error: cannot read " + label + " file: " + path)
      @env.exit(2)
    }
  }
}

///|
/// 审计报告摘要：只含类型、偏移、算子与规则版本，绝不含原文。
fn report_to_string(result : @core.RedactResult) -> String {
  let report = result.report
  let mut s = "rules_version=" + report.rules_version + "\n"
  s += "matched=" + report.matched_count.to_string() + "\n"
  s += "by_entity:\n"
  for pair in report.by_entity {
    s += "  " + pair.0 + "=" + pair.1.to_string() + "\n"
  }
  s += "by_operator:\n"
  for pair in report.by_operator {
    s += "  " + pair.0 + "=" + pair.1.to_string() + "\n"
  }
  s += "spans:\n"
  for span in report.spans {
    s += "  " +
      span.entity +
      " " +
      span.start.to_string() +
      "-" +
      span.end.to_string() +
      " operator=" +
      span.operator +
      " detector=" +
      span.detector +
      "\n"
  }
  s
}

///|
/// 机器可读输出：{"text":...,"count":...}。
fn json_result(result : @core.RedactResult) -> String {
  "{\"text\":\"" +
  escape_json_string(result.text) +
  "\",\"count\":" +
  result.report.matched_count.to_string() +
  "}"
}

///|
/// 程序入口。
fn main {
  let args = @env.args()
  if args.length() <= 1 || has_flag(args, "--help") {
    print_help()
    return
  }
  if has_flag(args, "--version") {
    println("veil 0.1.0")
    return
  }
  let rules_path = match arg_value(args, "--rules") {
    Some(p) => p
    None => {
      eprintln("error: --rules is required")
      @env.exit(2)
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
  let input_text = match arg_value(args, "--input") {
    Some(path) => read_text_file(path, "input")
    None =>
      match arg_value(args, "--text") {
        Some(text) => text
        None => {
          eprintln("error: one of --text or --input is required")
          @env.exit(2)
        }
      }
  }
  let rules_json = read_text_file(rules_path, "rules")
  let rs = match @core.load_ruleset(rules_json) {
    Ok(v) => v
    Err(e) => {
      let mut msg = "error: invalid ruleset:"
      for err in e.errors {
        msg += " " + err
      }
      eprintln(msg)
      @env.exit(2)
    }
  }
  let opts = @core.EngineOptions::{ key, enable_policy: false }
  let result = @core.redact(input_text, rs, opts)
  let out = if has_flag(args, "--dry-run") {
    report_to_string(result)
  } else if has_flag(args, "--json") {
    json_result(result)
  } else {
    result.text
  }
  match arg_value(args, "--output") {
    Some(path) => {
      try {
        @fs.write_string_to_file(path, out)
      } catch {
        _ => {
          eprintln("error: cannot write output file: " + path)
          @env.exit(2)
        }
      }
    }
    None => println(out)
  }
}
