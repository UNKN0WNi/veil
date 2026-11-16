// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 复合检测器：先按字段路径定位，再对字段值跑引用的子检测器。
// 文本轨是近似实现（在原文中搜 `"叶子键": "值"`），精确匹配走结构轨。

///|
/// 复合检测器：先按 field 定位，再对字段值跑引用的子检测器。
pub fn detect_composite(
  text : String,
  d : DetectorIR,
  order : Int32,
  ruleset : Ruleset,
  min_score : Double,
  out : Array[Detected],
) -> Unit {
  for target in d.targets {
    let leaf = last_segment(target)
    let needle = "\"" + leaf + "\""
    let chars = text.to_array()
    let na = needle.to_array()
    let mut from = 0
    while from <= chars.length() - na.length() {
      let idx = find_substring(chars, na, from)
      if idx < 0 {
        break
      }
      // 找冒号后的字符串值
      let mut p = idx + na.length()
      while p < chars.length() && (chars[p] == ' ' || chars[p] == ':') {
        p += 1
      }
      if p < chars.length() && chars[p] == '"' {
        let vstart = p + 1
        let mut q = vstart
        while q < chars.length() && chars[q] != '"' {
          q += 1
        }
        let value = text[:][vstart:q].to_owned()
        // 跑子检测器（简化：任一子检测器命中即采用）
        for sub_id in d.detectors {
          match find_detector(ruleset, sub_id) {
            Some(sub) if sub.pattern != "" => {
              let re = @string.Regex(sub.pattern) catch { _ => continue }
              if re.execute(value) is Some(_) {
                add_detection(text, value, vstart, q, d, order, min_score, out)
                break
              }
            }
            _ => ()
          }
        }
        from = q + 1
      } else {
        from = idx + na.length()
      }
    }
  }
}

///|
/// 取路径最后一段。
fn last_segment(path : String) -> String {
  let parts = path.split(".").to_array()
  if parts.length() == 0 {
    path
  } else {
    parts[parts.length() - 1].to_owned()
  }
}
