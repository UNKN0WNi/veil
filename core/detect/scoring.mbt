// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 上下文打分（计划书 §4.6）：
//   final_score = base + (命中上下文词 ? boost) - (命中反上下文词 ? penalty)
// 同一命中多个上下文词不叠加（取最高 boost），保证确定性。

///|
/// 取上下文窗口文本：命中区间前后各 window 个字符。
pub fn context_window(
  text : String,
  start : Int32,
  end : Int32,
  window : Int32,
) -> String {
  let len = text.length()
  let s = if start - window > 0 { start - window } else { 0 }
  let e = if end + window < len { end + window } else { len }
  text[:][s:e].to_owned()
}

///|
/// 计算上下文分值增量。
/// 命中任一 words → +boost（不叠加）；命中任一 anti_words → -penalty（不叠加）。
pub fn context_delta(
  text : String,
  start : Int32,
  end : Int32,
  conf : ContextConf,
) -> Double {
  let haystack = if conf.case_sensitive {
    context_window(text, start, end, conf.window)
  } else {
    context_window(text, start, end, conf.window).to_lower()
  }
  let mut hit_word = false
  for w in conf.words {
    let needle = if conf.case_sensitive { w } else { w.to_lower() }
    if needle.length() > 0 && haystack.contains(needle) {
      hit_word = true
      break
    }
  }
  let mut hit_anti = false
  for w in conf.anti_words {
    let needle = if conf.case_sensitive { w } else { w.to_lower() }
    if needle.length() > 0 && haystack.contains(needle) {
      hit_anti = true
      break
    }
  }
  let mut delta = 0.0
  if hit_word {
    delta += conf.boost
  }
  if hit_anti {
    delta -= conf.penalty
  }
  delta
}
