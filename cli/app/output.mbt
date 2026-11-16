// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 输出格式：审计报告 / JSON / 纯文本。审计输出绝不含原文。

///|
/// JSON 字符串转义（最小实现，与 js 入口保持一致）。
pub fn escape_json_string(s : String) -> String {
  let mut out = ""
  for c in s.to_array() {
    if c == '"' {
      out += "\\\""
    } else if c == '\\' {
      out += "\\\\"
    } else if c.to_int() == 10 {
      out += "\\n"
    } else if c.to_int() == 13 {
      out += "\\r"
    } else if c.to_int() == 9 {
      out += "\\t"
    } else {
      out += "\{c}"
    }
  }
  out
}

///|
/// 审计报告摘要：只含类型、偏移、算子与规则版本，绝不含原文。
pub fn report_to_string(result : @core.RedactResult) -> String {
  let report = result.report
  let mut s = "rules_version=" + report.rules_version + "\n"
  s += "matched=" + report.matched_count.to_string() + "\n"
  s += "by_entity:\n"
  for pair in report.by_entity {
    s += "  " + pair.0 + "=" + pair.1.to_string() + "\n"
  }
  s += "by_operator:\n"
  for pair in report.by_operator {
    s += "  " + pair.0 + "=" + pair.1.to_string() + "\n"
  }
  s += "spans:\n"
  for span in report.spans {
    s += "  " +
      span.entity +
      " " +
      span.start.to_string() +
      "-" +
      span.end.to_string() +
      " operator=" +
      span.operator +
      " detector=" +
      span.detector +
      "\n"
  }
  s
}

///|
/// 机器可读输出：{"text":...,"count":...}。
pub fn json_result(result : @core.RedactResult) -> String {
  "{\"text\":\"" +
  escape_json_string(result.text) +
  "\",\"count\":" +
  result.report.matched_count.to_string() +
  "}"
}
