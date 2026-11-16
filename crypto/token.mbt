// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 确定性令牌（计划书 §4.5 tokenize）：HMAC-SHA256(key, value)。
// 四后端字节一致（S0 已验证）；密钥只从调用方注入，绝不入配置/日志。

///|
/// 字节数组 → hex（内部）。
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
/// HMAC-SHA256 → hex 字符串。
pub fn hmac_sha256_hex(key : String, message : String) -> String {
  let mac = @xcrypto.hmac(
    @xcrypto.SHA256::new(),
    @encoding.encode(UTF8, key),
    @encoding.encode(UTF8, message),
  )
  bytes_to_hex(mac)
}

///|
/// 生成确定性令牌：前缀 + HMAC 摘要（可截断）。
pub fn tokenize(
  key : String,
  value : String,
  prefix : String,
  length : Int32,
) -> String {
  let full = hmac_sha256_hex(key, value)
  let body = if length > 0 && length < full.length() {
    full[:length]
  } else {
    full[:]
  }
  prefix + body.to_owned()
}

///|
/// SHA-256 → hex（仅用于高熵值；低熵值请用 hmac_sha256_hex，见 §6.3）。
pub fn sha256_hex(value : String) -> String {
  @xcrypto.bytes_to_hex_string(@xcrypto.sha256(@encoding.encode(UTF8, value)))
}
