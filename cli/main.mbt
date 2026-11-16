// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// veil CLI：原生可执行产物，只做流程编排（解析 → 读入 → 加载规则 → 脱敏 → 输出）。
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
/// 程序入口。
fn main {
  let argv = @env.args()
  let args = @app.parse_args(argv)
  if argv.length() <= 1 || args.help {
    print_help()
    return
  }
  if args.version {
    println("veil 0.1.0")
    return
  }
  let rules_path = match args.rules {
    Some(p) => p
    None => {
      eprintln("error: --rules is required")
      @env.exit(2)
    }
  }
  let key = match @env.get_env_var(args.key_env) {
    Some(k) => k
    None => ""
  }
  let input_text = match args.input {
    Some(path) => @app.read_text_file(path, "input")
    None =>
      match args.text {
        Some(text) => text
        None => {
          eprintln("error: one of --text or --input is required")
          @env.exit(2)
        }
      }
  }
  let rules_json = @app.read_text_file(rules_path, "rules")
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
  let opts = @core.EngineOptions::{ key, enable_policy: false, }
  let result = @core.redact(input_text, rs, opts)
  let out = if args.dry_run {
    @app.report_to_string(result)
  } else if args.json {
    @app.json_result(result)
  } else {
    result.text
  }
  match args.output {
    Some(path) => @app.write_text_file(path, out)
    None => println(out)
  }
}
