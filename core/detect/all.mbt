// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 检测调度：按规则声明顺序遍历检测器，统一做校验、上下文打分与阈值过滤。
// 数组顺序参与重叠消解，因此这里绝不重排或并发执行。

///|
/// 扫描所有检测器，返回候选命中（未消解）。
pub fn detect_all(
  text : String,
  ruleset : Ruleset,
  min_score : Double,
) -> Array[Detected] {
  let out : Array[Detected] = []
  for i = 0; i < ruleset.detections.length(); i = i + 1 {
    let d = ruleset.detections[i]
    match d.kind {
      Pattern => detect_pattern(text, d, i, min_score, out)
      Dictionary => detect_dictionary(text, d, i, min_score, out)
      Checksum => detect_checksum(text, d, i, min_score, out)
      Composite => detect_composite(text, d, i, ruleset, min_score, out)
      Field => () // 字段级在结构轨处理（本函数负责值级）
    }
  }
  out
}

///|
/// 构造一条 Detected：上下文打分 + 阈值过滤 + 算子选择。
pub fn add_detection(
  text : String,
  content : String,
  start : Int32,
  end : Int32,
  d : DetectorIR,
  order : Int32,
  min_score : Double,
  out : Array[Detected],
) -> Unit {
  if content.length() == 0 {
    return
  }
  // validator 是硬过滤：任何检测器类型都必须在打分前通过校验。
  if d.validator != "" && !validate(d.validator, content) {
    return
  }
  let delta = context_delta(text, start, end, d.context)
  let score = d.score + delta
  if score < min_score {
    return
  }
  let op_id = if d.action_id != "" { d.action_id } else { "" } // 空 = 用默认
  out.push(Detected::{
    span: Span::{ start, end, },
    detector_id: d.id,
    detector_order: order,
    entity: d.id,
    score,
    matched_by: [d.id],
    operator_id: op_id,
    text: content,
  })
}
