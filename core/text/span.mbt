// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// Span / Detected / 重叠消解。四后端共享的纯函数（计划书 §4.7）。

///|
/// 命中片段在原始文本中的区间（字符偏移，[start, end)）。
pub(all) struct Span {
  start : Int32
  end : Int32
}

///|
/// 一次检测命中：区间 + 分数 + 检测器信息 + 算子。
pub(all) struct Detected {
  span : Span
  /// 检测器 id（声明顺序用于消解同分冲突）
  detector_id : String
  /// 检测器在 detectors 数组中的下标（同分时小者优先）
  detector_order : Int32
  /// 实体类型（如 email / cn_phone）
  entity : String
  /// 最终分数（base + context boost - penalty）
  score : Double
  /// 同一片段被哪些检测器命中（记录全部，取声明最前者为主）
  mut matched_by : Array[String]
  /// 实际执行的算子 id
  operator_id : String
  /// 命中原文（仅在内存中，不写入审计报告）
  text : String
}

///|
/// 整数比较器（升序）：供 sort_by 使用。
pub fn cmp_int(a : Int32, b : Int32) -> Int32 {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
/// 两个区间是否相交（端点相接不算相交）。
pub fn Span::overlaps(self : Span, other : Span) -> Bool {
  self.start < other.end && other.start < self.end
}

///|
/// 区间长度。
pub fn Span::length(self : Span) -> Int32 {
  self.end - self.start
}

///|
/// 区间是否完全包含另一区间。
pub fn Span::contains(self : Span, other : Span) -> Bool {
  self.start <= other.start && self.end >= other.end
}

///|
/// 按分数/声明顺序/长度/起点排序的比较器（消解用）。
fn cmp_detection(a : Detected, b : Detected) -> Int32 {
  if a.score != b.score {
    // 分数降序
    if a.score > b.score {
      -1
    } else {
      1
    }
  } else if a.detector_order != b.detector_order {
    // 声明顺序升序
    cmp_int(a.detector_order, b.detector_order)
  } else if a.span.length() != b.span.length() {
    // 长 span 优先（降序）
    if a.span.length() > b.span.length() {
      -1
    } else {
      1
    }
  } else {
    cmp_int(a.span.start, b.span.start)
  }
}

///|
/// 确定性重叠消解（计划书 §4.7）：
/// 1. 分数高者优先；2. 同分 → 检测器声明顺序在前者优先；
/// 3. 完全包含时长 span 优先；4. 部分重叠取分数高者，另一方裁剪。
/// 返回保留的命中，按 start 升序（便于文本轨区间替换）。
pub fn resolve_overlaps(detections : Array[Detected]) -> Array[Detected] {
  let sorted = detections.copy()
  sorted.sort_by(cmp_detection)

  let kept : Array[Detected] = []
  for candidate in sorted {
    let mut conflict = false
    for i = 0; i < kept.length(); i = i + 1 {
      let k = kept[i]
      if candidate.span.overlaps(k.span) {
        // 合并 matched_by（同片段多检测器命中）
        let merged = k.matched_by.copy()
        for m in candidate.matched_by {
          if !merged.contains(m) {
            merged.push(m)
          }
        }
        k.matched_by = merged
        kept[i] = k
        conflict = true
        break
      }
    }
    if !conflict {
      kept.push(candidate)
    }
  }
  // 按 start 升序输出（文本轨替换需要）
  kept.sort_by(fn(a, b) { cmp_int(a.span.start, b.span.start) })
  kept
}

///|
/// 合并"完全同一区间"的命中：保留声明顺序最前者，合并 matched_by。
pub fn merge_same_span(detections : Array[Detected]) -> Array[Detected] {
  let result : Array[Detected] = []
  for d in detections {
    let mut found = -1
    for i = 0; i < result.length(); i = i + 1 {
      let r = result[i]
      if r.span.start == d.span.start && r.span.end == d.span.end {
        found = i
        break
      }
    }
    if found >= 0 {
      let r = result[found]
      if d.detector_order < r.detector_order {
        let merged = d.matched_by.copy()
        for m in r.matched_by {
          if !merged.contains(m) {
            merged.push(m)
          }
        }
        d.matched_by = merged
        result[found] = d
      } else {
        let merged = r.matched_by.copy()
        for m in d.matched_by {
          if !merged.contains(m) {
            merged.push(m)
          }
        }
        r.matched_by = merged
      }
    } else {
      result.push(d)
    }
  }
  result
}
