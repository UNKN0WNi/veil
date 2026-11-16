// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 确定性 JSON 序列化（计划书 §5.3）：
// - 按 Object 数组下标输出（保序）
// - Number 直接输出原文（保精度）
// - 字符串按 JSON 规范转义，四后端一致

///|
/// 序列化为 JSON 字符串。
pub fn write_json(value : JsonValue) -> String {
  match value {
    Null => "null"
    Bool(true) => "true"
    Bool(false) => "false"
    Number(n) => n
    Str(s) => quote_string(s)
    Array(items) => {
      let mut out = "["
      for i = 0; i < items.length(); i = i + 1 {
        if i > 0 {
          out += ","
        }
        out += write_json(items[i])
      }
      out += "]"
      out
    }
    Object(pairs) => {
      let mut out = "{"
      for i = 0; i < pairs.length(); i = i + 1 {
        if i > 0 {
          out += ","
        }
        out += quote_string(pairs[i].0)
        out += ":"
        out += write_json(pairs[i].1)
      }
      out += "}"
      out
    }
  }
}

///|
/// JSON 字符串转义（含控制字符与 Unicode 码点）。
fn quote_string(s : String) -> String {
  let mut out = "\""
  for c in s.to_array() {
    let x = c.to_int()
    if c == '"' {
      out += "\\\""
    } else if c == '\\' {
      out += "\\\\"
    } else if x == 8 {
      out += "\\b"
    } else if x == 9 {
      out += "\\t"
    } else if x == 10 {
      out += "\\n"
    } else if x == 12 {
      out += "\\f"
    } else if x == 13 {
      out += "\\r"
    } else if x < 32 {
      out += "\\u00"
      let h = "0123456789abcdef".to_array()
      out += String::from_array([h[x / 16 % 16], h[x % 16]])
    } else {
      out += "\{c}"
    }
  }
  out += "\""
  out
}

///|
/// 在有序 AST 中按路径设置值（结构轨：整字段替换）。
/// path 用 `.` 分隔；`*` 暂不支持写入（写入用精确路径）。
/// 返回是否找到并替换。
pub fn set_path(
  root : JsonValue,
  path : String,
  new_value : JsonValue,
) -> JsonValue {
  let segs = path.split(".").to_array().map(fn(x) { x.to_owned() })
  set_path_rec(root, segs, 0, new_value)
}

///|
/// 递归设置。
fn set_path_rec(
  node : JsonValue,
  segs : Array[String],
  idx : Int32,
  new_value : JsonValue,
) -> JsonValue {
  if idx >= segs.length() {
    return new_value
  }
  match node {
    Object(pairs) => {
      let out : Array[(String, JsonValue)] = []
      let mut found = false
      for pair in pairs {
        if pair.0 == segs[idx] {
          out.push((pair.0, set_path_rec(pair.1, segs, idx + 1, new_value)))
          found = true
        } else {
          out.push(pair)
        }
      }
      if !found {
        out.push((segs[idx], set_path_rec(Null, segs, idx + 1, new_value)))
      }
      Object(out)
    }
    Array(items) => {
      // 数字段名作为数组下标
      let out = items.copy()
      match int_of_string(segs[idx]) {
        Some(i) if i >= 0 && i < out.length() => {
          out[i] = set_path_rec(out[i], segs, idx + 1, new_value)
          ()
        }
        _ => ()
      }
      Array(out)
    }
    _ => set_path_rec(Null, segs, idx, new_value)
  }
}

///|
/// 字符串转整数（数组下标用）。
fn int_of_string(s : String) -> Int32? {
  if s.length() == 0 {
    return None
  }
  let mut val = 0
  for c in s.to_array() {
    let x = c.to_int()
    if x < 48 || x > 57 {
      return None
    }
    val = val * 10 + (x - 48)
  }
  Some(val)
}

///|
/// 在有序 AST 中按路径读取值。
pub fn get_path(root : JsonValue, path : String) -> JsonValue? {
  let segs = path.split(".").to_array().map(fn(x) { x.to_owned() })
  get_path_rec(root, segs, 0)
}

///|
/// 递归读取。
fn get_path_rec(
  node : JsonValue,
  segs : Array[String],
  idx : Int32,
) -> JsonValue? {
  if idx >= segs.length() {
    return Some(node)
  }
  match node {
    Object(pairs) => {
      for pair in pairs {
        if pair.0 == segs[idx] {
          return get_path_rec(pair.1, segs, idx + 1)
        }
      }
      None
    }
    Array(items) =>
      match int_of_string(segs[idx]) {
        Some(i) if i >= 0 && i < items.length() =>
          get_path_rec(items[i], segs, idx + 1)
        _ => None
      }
    _ => None
  }
}
