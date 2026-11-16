// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 校验和检测器：正则提取候选，再交给 validator 做硬校验。
// 典型用途：身份证 / 银行卡 / USCC / IMEI / ISBN —— "长得像"必须"算得过"。

///|
/// 校验和检测器：正则提取候选 + validator 过滤。
pub fn detect_checksum(
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
    let content = m.content().to_owned()
    if !validate(d.validator, content) {
      continue
    }
    let start = m.before().to_owned().length()
    let end = start + content.length()
    add_detection(text, content, start, end, d, order, min_score, out)
  }
}
