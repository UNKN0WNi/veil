// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// veil/core 的对外门面：把子包的公开 API 原样再导出，
// 调用方（js / wasm / cli / 下游 MoonBit 模块）只需 import { "veil/core" }。

///|
/// Span / Detected / 重叠消解。
pub using @text {
  type Span,
  type Detected,
  resolve_overlaps,
  merge_same_span,
  cmp_int,
}

///|
/// 有序 JSON AST、解析 / 序列化、JSON 路径。
pub using @json {
  type JsonValue,
  type JsonParseError,
  parse_json,
  write_json,
  set_path,
  get_path,
  path_match,
  path_match_any,
}

///|
/// 算子：配置结构与执行。
pub using @ops {
  type Operator,
  apply_operator,
  hmac_sha256_hex,
  is_operator_type,
}

///|
/// 校验器：Luhn / 身份证 / 银行卡 / USCC / ISBN / IMEI / IP / Base64 / JWT。
pub using @validate {
  validate,
  is_validator,
  luhn,
  cn_id_checksum,
  cn_bank_card_checksum,
  cn_uscc_checksum,
  isbn,
  imei,
  ipv4,
  ipv6,
  base64,
  jwt,
}

///|
/// 规则集：IR、加载与查找。
pub using @rules {
  type DetectorKind,
  type DetectorIR,
  type PolicyIR,
  type Ruleset,
  type RuleLoadError,
  type ContextConf,
  load_ruleset,
  build_ruleset,
  find_detector,
  find_operator,
}

///|
/// 上下文打分（供自定义检测器复用）。
pub using @detect {context_delta, context_window}

///|
/// 结构轨：格式探测 + JSON fail-closed 过滤 / 按路径替换。
pub using @structure {
  type InputFormat,
  detect_format,
  format_name,
  redact_json_policy,
  redact_json_fields,
}
