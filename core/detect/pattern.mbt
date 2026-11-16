// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 字面 / 正则扫描：pattern 与 dictionary 两类检测器。
// 两者都只负责产出候选区间，打分与过滤统一由 all.mbt 的 add_detection 负责。

///|
/// 正则检测器：用 lexmatch 正则扫描（@string.Regex）。
pub fn detect_pattern(
  text : String,
  d : DetectorIR,
  order : Int32,
  min_score : Double,
  out : Array[Detected],
) -> Unit {
  if d.pattern == "" {
    return
  }
  let re = @string.Regex(d.pattern) catch { _ => return }
  for m in re.find(text) {
    let before = m.before().to_owned()
    let content = m.content().to_owned()
    let start = before.length()
    let end = start + content.length()
    add_detection(text, content, start, end, d, order, min_score, out)
  }
}

///|
/// 词典检测器：子串匹配（可选大小写不敏感）。
pub fn detect_dictionary(
  text : String,
  d : DetectorIR,
  order : Int32,
  min_score : Double,
  out : Array[Detected],
) -> Unit {
  let chars = if d.case_sensitive {
    text.to_array()
  } else {
    text.to_lower().to_array()
  }
  for term in d.terms {
    let needle = if d.case_sensitive { term } else { term.to_lower() }
    if needle.length() == 0 {
      continue
    }
    let mut from = 0
    while from <= chars.length() - needle.length() {
      let idx = find_substring(chars, needle.to_array(), from)
      if idx < 0 {
        break
      }
      // 命中原文（用原始 text 的对应偏移）
      let end = idx + needle.length()
      let original = text[:][idx:end].to_owned()
      add_detection(text, original, idx, end, d, order, min_score, out)
      from = idx + needle.length()
    }
  }
}

///|
/// 子串查找（字符数组，返回起始下标，-1 表示未找到）。
pub fn find_substring(
  hay : Array[Char],
  needle : Array[Char],
  from : Int32,
) -> Int32 {
  if needle.length() == 0 || from > hay.length() - needle.length() {
    return -1
  }
  for i = from; i <= hay.length() - needle.length(); i = i + 1 {
    let mut ok = true
    for j = 0; j < needle.length(); j = j + 1 {
      if hay[i + j] != needle[j] {
        ok = false
        break
      }
    }
    if ok {
      return i
    }
  }
  -1
}
