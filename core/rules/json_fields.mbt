// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// JSON 取值辅助：把"字段缺失 / 类型不符"统一收敛成默认值，避免各处重复判断。

///|
/// 读取字符串字段（带默认值）。
fn jstr(j : JsonValue, key : String, default : String) -> String {
  match j.get(key) {
    Some(v) =>
      match v.as_str() {
        Some(s) => s
        None => default
      }
    None => default
  }
}

///|
/// 读取数值字段为 Double。
fn jnum(j : JsonValue, key : String, default : Double) -> Double {
  match j.get(key) {
    Some(v) =>
      match v.as_double() {
        Some(n) => n
        None => default
      }
    None => default
  }
}

///|
/// 读取数值字段为 Int。
fn jint(j : JsonValue, key : String, default : Int32) -> Int32 {
  match j.get(key) {
    Some(v) =>
      match v.as_double() {
        Some(n) => n.to_int()
        None => default
      }
    None => default
  }
}

///|
/// 读取布尔字段。
fn jbool(j : JsonValue, key : String, default : Bool) -> Bool {
  match j.get(key) {
    Some(v) =>
      match v.as_bool() {
        Some(b) => b
        None => default
      }
    None => default
  }
}

///|
/// 读取 JSON 字符串数组字段。
fn jarray(j : JsonValue, key : String) -> Array[String] {
  let out : Array[String] = []
  match j.get(key) {
    Some(v) =>
      match v.as_array() {
        Some(arr) =>
          for item in arr {
            if item.as_str() is Some(s) {
              out.push(s)
            }
          }
        None => ()
      }
    None => ()
  }
  out
}

///|
