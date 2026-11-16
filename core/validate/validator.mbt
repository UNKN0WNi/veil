// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 内置校验器：对候选片段做算法级校验以降误报。
// 全部为纯函数，四后端一致。

///|
/// 字符是否为 ASCII 数字。
fn is_digit(c : Char) -> Bool {
  let x = c.to_int()
  x >= 48 && x <= 57
}

///|
/// 仅保留数字字符（忽略空格与连字符）。
fn digits_only(s : String) -> String {
  let mut out = ""
  for c in s.to_array() {
    if is_digit(c) {
      out = out + "\{c}"
    }
  }
  out
}

///|
/// Luhn 校验（信用卡 / IMEI / 银行卡）。
pub fn luhn(s : String) -> Bool {
  let d = digits_only(s)
  if d.length() < 2 || d.length() > 19 {
    return false
  }
  let chars = d.to_array()
  let mut sum = 0
  let mut alt = false
  let mut i = d.length() - 1
  while i >= 0 {
    let mut n = chars[i].to_int() - 48
    if alt {
      n = n * 2
      if n > 9 {
        n -= 9
      }
    }
    sum += n
    alt = !alt
    i -= 1
  }
  sum % 10 == 0
}

///|
/// 中国居民身份证校验（GB 11643，18 位加权模 11）。
pub fn cn_id_checksum(s : String) -> Bool {
  let raw = s.to_lower()
  if raw.length() != 18 {
    return false
  }
  let chars = raw.to_array()
  // 前 17 位必须全为数字
  for i = 0; i < 17; i = i + 1 {
    if !is_digit(chars[i]) {
      return false
    }
  }
  let weights = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2]
  let codes = "10x98765432".to_array()
  let mut sum = 0
  for i = 0; i < 17; i = i + 1 {
    sum += (chars[i].to_int() - 48) * weights[i]
  }
  let check = codes[sum % 11]
  check == chars[17]
}

///|
/// 中国大陆银行卡校验：13–19 位，Luhn（ISO/IEC 7812）。
pub fn cn_bank_card_checksum(s : String) -> Bool {
  let d = digits_only(s)
  if d.length() < 13 || d.length() > 19 {
    return false
  }
  luhn(d)
}

///|
/// 统一社会信用代码校验（GB 32100，18 位）。
/// 字符集：0123456789ABCDEFGHJKLMNPQRTUWXY（不含 I O S V Z）。
pub fn cn_uscc_checksum(s : String) -> Bool {
  let raw = s.to_upper()
  if raw.length() != 18 {
    return false
  }
  let charset = "0123456789ABCDEFGHJKLMNPQRTUWXY"
  let set = charset.to_array()
  let weights = [1, 3, 9, 27, 19, 26, 16, 17, 20, 29, 25, 13, 8, 24, 10, 30, 28]
  let chars = raw.to_array()
  let mut sum = 0
  for i = 0; i < 17; i = i + 1 {
    let mut pos = -1
    for j = 0; j < set.length(); j = j + 1 {
      if set[j] == chars[i] {
        pos = j
        break
      }
    }
    if pos < 0 {
      return false
    }
    sum += pos * weights[i]
  }
  let check = 31 - sum % 31
  let expected = set[if check == 31 { 0 } else { check }]
  expected == chars[17]
}

///|
/// 全局替换（MoonBit 的 String.replace 只替换首个匹配）。
fn replace_all(s : String, old : String, new : String) -> String {
  let mut out = s
  while out.contains(old) {
    out = out.replace(old~, new~)
  }
  out
}

///|
/// ISBN-10 / ISBN-13 校验。
pub fn isbn(s : String) -> Bool {
  let raw = replace_all(replace_all(s, "-", ""), " ", "")
  let chars = raw.to_array()
  if raw.length() == 10 {
    let mut sum = 0
    for i = 0; i < 9; i = i + 1 {
      if !is_digit(chars[i]) {
        return false
      }
      sum += (chars[i].to_int() - 48) * (10 - i)
    }
    let last = chars[9].to_int()
    let check = if last == 88 {
      10
    } else if is_digit(chars[9]) {
      last - 48
    } else {
      return false
    }
    (sum + check) % 11 == 0
  } else if raw.length() == 13 {
    let d = digits_only(raw)
    if d.length() != 13 {
      return false
    }
    let dc = d.to_array()
    let mut sum = 0
    for i = 0; i < 12; i = i + 1 {
      let n = dc[i].to_int() - 48
      sum += if i % 2 == 0 { n } else { n * 3 }
    }
    let check = (10 - sum % 10) % 10
    check == dc[12].to_int() - 48
  } else {
    false
  }
}

///|
/// IMEI 校验（15 位，Luhn）。
pub fn imei(s : String) -> Bool {
  let d = digits_only(s)
  d.length() == 15 && luhn(d)
}

///|
/// IPv4 校验（4 段十进制，0–255）。
pub fn ipv4(s : String) -> Bool {
  let parts = s.split(".").to_array()
  if parts.length() != 4 {
    return false
  }
  for p in parts {
    if p.length() == 0 || p.length() > 3 {
      return false
    }
    let mut val = 0
    for c in p.to_array() {
      if !is_digit(c) {
        return false
      }
      val = val * 10 + (c.to_int() - 48)
    }
    if val > 255 {
      return false
    }
  }
  true
}

///|
/// IPv6 校验（含 `::` 压缩，段数 ≤ 8，十六进制）。
pub fn ipv6(s : String) -> Bool {
  if s.contains(".") {
    return false // mixed IPv4-mapped 不在内置范围
  }
  let parts = s.split(":").to_array()
  let mut groups = 0
  let mut empties = 0
  for p in parts {
    if p.length() == 0 {
      empties += 1
    } else {
      if p.length() > 4 {
        return false
      }
      for c in p.to_array() {
        let x = c.to_int()
        let ok = is_digit(c) || (x >= 97 && x <= 102) || (x >= 65 && x <= 70)
        if !ok {
          return false
        }
      }
      groups += 1
    }
  }
  if empties >= 2 {
    return false // 只允许一个 `::`
  }
  if empties == 1 {
    groups <= 7
  } else {
    groups == 8
  }
}

///|
/// base64 疑似凭据校验：长度 4 的倍数，字符集合法，尾部填充 ≤ 2。
pub fn base64(s : String) -> Bool {
  if s.length() < 16 || s.length() % 4 != 0 {
    return false
  }
  let mut pad = 0
  for c in s.to_array() {
    let x = c.to_int()
    let valid = (x >= 65 && x <= 90) ||
      (x >= 97 && x <= 122) ||
      is_digit(c) ||
      x == 43 ||
      x == 47 ||
      x == 61
    if !valid {
      return false
    }
    if x == 61 {
      pad += 1
    }
  }
  pad <= 2
}

///|
/// JWT 结构校验：三段 base64url，第一段以 eyJ 开头（{"alg" 的 base64url 前缀）。
pub fn jwt(s : String) -> Bool {
  let parts = s.split(".").to_array()
  if parts.length() != 3 {
    return false
  }
  for p in parts {
    if p.length() == 0 {
      return false
    }
    for c in p.to_array() {
      let x = c.to_int()
      let ok = (x >= 65 && x <= 90) ||
        (x >= 97 && x <= 122) ||
        is_digit(c) ||
        x == 45 ||
        x == 95
      if !ok {
        return false
      }
    }
  }
  parts[0].has_prefix("eyJ")
}

///|
/// 按名称调用校验器。未知名称返回 false（规则加载期会拒绝未知引用）。
pub fn validate(name : String, s : String) -> Bool {
  match name {
    "luhn" => luhn(s)
    "cn_id_checksum" => cn_id_checksum(s)
    "cn_bank_card_checksum" => cn_bank_card_checksum(s)
    "cn_uscc_checksum" => cn_uscc_checksum(s)
    "isbn" => isbn(s)
    "imei" => imei(s)
    "ipv4" => ipv4(s)
    "ipv6" => ipv6(s)
    "base64" => base64(s)
    "jwt" => jwt(s)
    _ => false
  }
}

///|
/// 名称是否为内置校验器。
pub fn is_validator(name : String) -> Bool {
  let names = [
    "luhn", "cn_id_checksum", "cn_bank_card_checksum", "cn_uscc_checksum", "isbn",
    "imei", "ipv4", "ipv6", "base64", "jwt",
  ]
  names.contains(name)
}
