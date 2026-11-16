// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 有序 JSON 值类型：
// - Number(String) 保留数字原文，避免大整数精度丢失
// - Object(Array[(String, JsonValue)]) 保留键插入顺序
// 这是自研最小 AST，结构轨与规则集加载共用同一套表示。

///|
/// 有序 JSON 值。
pub(all) enum JsonValue {
  Null
  Bool(Bool)
  /// 保留数字原始文本（不转 Double）
  Number(String)
  Str(String)
  Array(Array[JsonValue])
  /// 有序：数组下标即输出顺序
  Object(Array[(String, JsonValue)])
}

///|
/// 取对象字段（非对象或字段缺失返回 None）。
pub fn JsonValue::get(self : JsonValue, key : String) -> JsonValue? {
  match self {
    Object(pairs) => {
      for pair in pairs {
        if pair.0 == key {
          return Some(pair.1)
        }
      }
      None
    }
    _ => None
  }
}

///|
/// 取出字符串值。
pub fn JsonValue::as_str(self : JsonValue) -> String? {
  match self {
    Str(s) => Some(s)
    _ => None
  }
}

///|
/// 取出布尔值。
pub fn JsonValue::as_bool(self : JsonValue) -> Bool? {
  match self {
    Bool(b) => Some(b)
    _ => None
  }
}

///|
/// 取出数组。
pub fn JsonValue::as_array(self : JsonValue) -> Array[JsonValue]? {
  match self {
    Array(items) => Some(items)
    _ => None
  }
}

///|
/// 取出对象键值对。
pub fn JsonValue::as_object(self : JsonValue) -> Array[(String, JsonValue)]? {
  match self {
    Object(pairs) => Some(pairs)
    _ => None
  }
}

///|
/// 取出数值：把 Number 的原文解析成 Double。
/// 规则配置只用于 score / min_score 这类小数值，手写解析足够且四端一致。
pub fn JsonValue::as_double(self : JsonValue) -> Double? {
  match self {
    Number(raw) => Some(parse_decimal(raw))
    _ => None
  }
}

///|
/// 取出整数（数值原文的小数部分截断）。
pub fn JsonValue::as_int(self : JsonValue) -> Int32? {
  match self {
    Number(raw) => Some(parse_decimal(raw).to_int())
    _ => None
  }
}

///|
/// 十进制文本 → Double。支持可选符号、小数与指数，不依赖平台解析函数。
fn parse_decimal(raw : String) -> Double {
  let chars = raw.to_array()
  let n = chars.length()
  let mut i = 0
  let mut sign = 1.0
  if i < n && (chars[i] == '-' || chars[i] == '+') {
    if chars[i] == '-' {
      sign = -1.0
    }
    i += 1
  }
  let mut int_part = 0.0
  while i < n && is_digit(chars[i]) {
    int_part = int_part * 10.0 + digit_value(chars[i])
    i += 1
  }
  let mut frac_part = 0.0
  let mut scale = 1.0
  if i < n && chars[i] == '.' {
    i += 1
    while i < n && is_digit(chars[i]) {
      frac_part = frac_part * 10.0 + digit_value(chars[i])
      scale = scale * 10.0
      i += 1
    }
  }
  let mut value = int_part + frac_part / scale
  if i < n && (chars[i] == 'e' || chars[i] == 'E') {
    i += 1
    let mut exp_sign = 1
    if i < n && (chars[i] == '-' || chars[i] == '+') {
      if chars[i] == '-' {
        exp_sign = -1
      }
      i += 1
    }
    let mut exp = 0
    while i < n && is_digit(chars[i]) {
      exp = exp * 10 + (chars[i].to_int() - 48)
      i += 1
    }
    for k = 0; k < exp; k = k + 1 {
      value = if exp_sign > 0 { value * 10.0 } else { value / 10.0 }
    }
  }
  sign * value
}

///|
/// 是否为 ASCII 数字。
fn is_digit(c : Char) -> Bool {
  c.to_int() >= 48 && c.to_int() <= 57
}

///|
/// ASCII 数字字符 → 数值。
fn digit_value(c : Char) -> Double {
  (c.to_int() - 48).to_double()
}
