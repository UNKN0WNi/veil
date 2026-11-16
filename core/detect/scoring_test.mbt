// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
// 上下文打分单测：boost 与 penalty 各命中一次，不叠加。

///|
test "context delta boost and anti" {
  let conf = @rules.ContextConf::{
    words: ["手机"],
    anti_words: ["订单"],
    window: 20,
    boost: 0.45,
    penalty: 0.3,
    case_sensitive: false,
  }
  let d1 = @detect.context_delta("手机: 13800138000", 4, 15, conf)
  assert_true(d1 > 0.0)
  let d2 = @detect.context_delta("订单: 13800138000", 4, 15, conf)
  assert_true(d2 < 0.0)
}
