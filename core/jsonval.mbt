// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 有序 JSON 值类型（计划书 §5.3）：
// - Number(String) 保留数字原文，避免大整数精度丢失
// - Object(Array[(String, JsonValue)]) 保留键插入顺序
// 这是自研最小 AST，仅用于结构轨（路径定位 + 整字段替换 + 确定性序列化）。

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
/// 从 core/json 的 Json 转换为有序 JsonValue（用于规则配置的内部表示）。
/// 注意：core/json 的 Object 是 Map，顺序不保证；规则语义不依赖对象键顺序（§6.2）。
pub fn from_core_json(j : @json.Json) -> JsonValue {
  match j {
    _ if j.as_null() is Some(_) => Null
    _ if j.as_bool() is Some(b) => Bool(b)
    _ if j.as_string() is Some(s) => Str(s)
    _ if j.as_number() is Some(n) => Number("{n}")
    _ if j.as_array() is Some(arr) => {
      let out : Array[JsonValue] = []
      for item in arr {
        out.push(from_core_json(item))
      }
      Array(out)
    }
    _ if j.as_object() is Some(map) => {
      let out : Array[(String, JsonValue)] = []
      for key in map.keys() {
        out.push((key, from_core_json(map[key])))
      }
      Object(out)
    }
    _ => Null
  }
}
