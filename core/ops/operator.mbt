// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 内置算子：
// redact / replace / mask / hash / tokenize / encrypt / keep。
// 全部确定性（相同输入+密钥 → 相同输出），四后端字节一致。

///|
/// 字节数组 → hex 字符串。
fn bytes_to_hex(bytes : FixedArray[Byte]) -> String {
  let digits = "0123456789abcdef".to_array()
  let mut s = ""
  for i = 0; i < bytes.length(); i = i + 1 {
    let n = bytes[i].to_int()
    s = s + String::from_array([digits[n / 16], digits[n % 16]])
  }
  s
}

///|
/// HMAC-SHA256 → hex（四后端字节一致）。
pub fn hmac_sha256_hex(key : String, message : String) -> String {
  let mac = @crypto.hmac(
    @crypto.SHA256::new(),
    @encoding.encode(UTF8, key),
    @encoding.encode(UTF8, message),
  )
  bytes_to_hex(mac)
}

///|
/// 算子配置（JSON operators[] 中的一条）。
pub(all) struct Operator {
  mut id : String
  /// redact | replace | mask | hash | tokenize | encrypt | keep
  mut type_ : String
  /// replace 的替换文本
  mut replacement : String
  /// mask：保留前 prefix / 后 suffix 个字符
  mut keep_prefix : Int32
  mut keep_suffix : Int32
  /// mask 填充字符
  mut fill : String
  /// hash/tokenize/encrypt 的前缀与长度
  mut prefix : String
  mut length : Int32
  /// 哈希算法（hmac_sha256 / sha256）
  mut algo : String
}

///|
/// 默认算子配置。
pub fn Operator::default() -> Operator {
  {
    id: "default",
    type_: "redact",
    replacement: "",
    keep_prefix: 0,
    keep_suffix: 0,
    fill: "*",
    prefix: "",
    length: 0,
    algo: "hmac_sha256",
  }
}

///|
/// 执行算子。key 用于 hash/tokenize/encrypt；censor 用于 redact 的默认替换。
pub fn apply_operator(
  op : Operator,
  value : String,
  key : String,
  censor : String,
) -> String {
  match op.type_ {
    "redact" => censor
    "replace" => op.replacement
    "keep" => value
    "mask" => apply_mask(value, op.keep_prefix, op.keep_suffix, op.fill)
    "hash" => {
      let digest = if op.algo == "sha256" {
        @crypto.bytes_to_hex_string(
          @crypto.sha256(@encoding.encode(UTF8, value)),
        )
      } else {
        hmac_sha256_hex(key, value)
      }
      let d = if op.length > 0 && op.length < digest.length() {
        digest[:op.length]
      } else {
        digest[:]
      }
      op.prefix + d.to_owned()
    }
    "tokenize" => {
      // 确定性令牌：HMAC(key, "tok|" + value)，可选前缀与长度。
      let digest = hmac_sha256_hex(key, "tok|" + value)
      let d = if op.length > 0 && op.length < digest.length() {
        digest[:op.length]
      } else {
        digest[:]
      }
      op.prefix + d.to_owned()
    }
    "encrypt" => {
      // v0.1：确定性可逆令牌（占位 gold token）。
      // 真正 AES-GCM 金库留 v1（x/crypto 无 GCM 原语，见实施计划）。
      let digest = hmac_sha256_hex(key, "enc|" + value)
      let d = if op.length > 0 && op.length < digest.length() {
        digest[:op.length]
      } else {
        digest[:]
      }
      op.prefix + d.to_owned() + "|rev"
    }
    _ => censor // 未知算子 → fail-closed：脱敏
  }
}

///|
/// 遮蔽：保留前 prefix / 后 suffix，中间用 fill 填充。
fn apply_mask(
  value : String,
  prefix : Int32,
  suffix : Int32,
  fill : String,
) -> String {
  let chars = value.to_array()
  let n = chars.length()
  let p = if prefix > 0 { prefix } else { 0 }
  let s = if suffix > 0 { suffix } else { 0 }
  if p + s >= n {
    // 保留全部（不足以遮蔽）
    return value
  }
  let head = String::from_array(chars[:p])
  let tail = if s > 0 { String::from_array(chars[n - s:]) } else { "" }
  let middle_len = n - p - s
  let mut mid = ""
  for ii = 0; ii < middle_len; ii = ii + 1 {
    mid += fill
  }
  head + mid + tail
}

///|
/// 是否为内置算子类型。
pub fn is_operator_type(t : String) -> Bool {
  let types = [
    "redact", "replace", "mask", "hash", "tokenize", "encrypt", "keep",
  ]
  types.contains(t)
}
