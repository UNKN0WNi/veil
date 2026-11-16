// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
// 重叠消解单测：分数优先，同分按声明顺序。

///|
test "overlap resolution deterministic" {
  let d1 = @text.Detected::{
    span: @text.Span::{ start: 0, end: 5, },
    detector_id: "a",
    detector_order: 0,
    entity: "a",
    score: 0.9,
    matched_by: ["a"],
    operator_id: "",
    text: "aaaaa",
  }
  let d2 = @text.Detected::{
    span: @text.Span::{ start: 3, end: 8, },
    detector_id: "b",
    detector_order: 1,
    entity: "b",
    score: 0.5,
    matched_by: ["b"],
    operator_id: "",
    text: "bbbbb",
  }
  let resolved = @text.resolve_overlaps([d1, d2])
  assert_eq(resolved.length(), 1)
  assert_eq(resolved[0].detector_id, "a")
}
