// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
//
// 可逆金库（encrypt / tokenize + vault）：
// 确定性 token ↔ 原值映射。v0.1 用内存映射（token = HMAC(key, value)），
// 同一 value 恒定映射到同一 token；restore 查映射表。
// 注意：映射表是进程内状态，四后端一致性仅保证 token 生成，不保证跨进程 restore。

///|
/// 金库条目。
struct VaultEntry {
  token : String
  value : String
}

///|
/// 金库（进程内可逆映射）。
pub(all) struct Vault {
  mut entries : Array[VaultEntry]
  mut key : String
  mut prefix : String
}

///|
/// 创建金库。
pub fn Vault::new(key : String) -> Vault {
  { entries: [], key, prefix: "[V:", }
}

///|
/// 存入原值，返回确定性 token；重复存入同一值返回同一 token。
pub fn Vault::seal(self : Vault, value : String) -> String {
  let token = hmac_sha256_hex(self.key, value)
  let full = self.prefix + token + "]"
  for i = 0; i < self.entries.length(); i = i + 1 {
    if self.entries[i].value == value {
      return full
    }
  }
  self.entries.push(VaultEntry::{ token: full, value, })
  full
}

///|
/// 按 token 还原原值；未找到返回 None。
pub fn Vault::restore(self : Vault, token : String) -> String? {
  for e in self.entries {
    if e.token == token {
      return Some(e.value)
    }
  }
  None
}

///|
/// 金库条目数。
pub fn Vault::size(self : Vault) -> Int32 {
  self.entries.length()
}
