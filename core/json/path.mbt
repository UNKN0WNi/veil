// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 结构化路径匹配（计划书 §4.8）：精确 / 单层通配 `*` / 前缀通配 `*.suffix`。

///|
/// 按 `.` 分割路径为段数组。
fn split_path(path : String) -> Array[String] {
  path.split(".").to_array().map(fn(x) { x.to_owned() })
}

///|
/// 单层段匹配：`*` 匹配任意单段，否则精确相等。
fn segment_match(pattern : String, actual : String) -> Bool {
  pattern == "*" || pattern == actual
}

///|
/// 路径匹配：段数相同、逐段匹配（`*` 为单层通配）。
/// 支持 `user.email` / `user.*.phone` / `*.token`。
pub fn path_match(pattern : String, path : String) -> Bool {
  let pp = split_path(pattern)
  let ap = split_path(path)
  if pp.length() != ap.length() {
    return false
  }
  for i = 0; i < pp.length(); i = i + 1 {
    if !segment_match(pp[i], ap[i]) {
      return false
    }
  }
  true
}

///|
/// 只要任一 pattern 匹配 path 即为 true。
pub fn path_match_any(patterns : Array[String], path : String) -> Bool {
  for p in patterns {
    if path_match(p, path) {
      return true
    }
  }
  false
}
