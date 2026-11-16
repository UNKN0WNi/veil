// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 上下文打分配置：作为规则 IR 的一部分（每个检测器可带自己的上下文窗口）。

///|
/// 上下文配置。
pub(all) struct ContextConf {
  mut words : Array[String]
  mut anti_words : Array[String]
  mut window : Int32
  mut boost : Double
  mut penalty : Double
  mut case_sensitive : Bool
}

///|
/// 默认上下文配置（无词、窗口 24、boost 0）。
pub fn ContextConf::default() -> ContextConf {
  {
    words: [],
    anti_words: [],
    window: 24,
    boost: 0.0,
    penalty: 0.0,
    case_sensitive: false,
  }
}
