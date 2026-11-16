// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 本包内部的名字导入。

///|
using @json {
  type JsonValue,
  type JsonParseError,
  parse_json,
  write_json,
  set_path,
  path_match_any,
}

///|
using @rules {type Ruleset, type PolicyIR}
