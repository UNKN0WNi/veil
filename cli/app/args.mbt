// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 参数解析：把 argv 解析成结构化 Args，供 main 只做流程编排。

///|
/// 解析后的命令行参数。
pub(all) struct Args {
  text : String?
  input : String?
  rules : String?
  output : String?
  key_env : String
  dry_run : Bool
  json : Bool
  version : Bool
  help : Bool
}

///|
/// 解析 argv（含 argv[0]）。
pub fn parse_args(argv : ArrayView[String]) -> Args {
  Args::{
    text: arg_value(argv, "--text"),
    input: arg_value(argv, "--input"),
    rules: arg_value(argv, "--rules"),
    output: arg_value(argv, "--output"),
    key_env: match arg_value(argv, "--key-env") {
      Some(n) => n
      None => "VEIL_KEY"
    },
    dry_run: has_flag(argv, "--dry-run"),
    json: has_flag(argv, "--json"),
    version: has_flag(argv, "--version"),
    help: has_flag(argv, "--help"),
  }
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
