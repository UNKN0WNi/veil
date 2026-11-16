// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0

///|
test "hmac known vector" {
  assert_eq(
    @crypto.hmac_sha256_hex("secret-key", "hello@example.com"),
    "928bc0a4262ca7746556831aee52ee3edfb53b2efd95c57a8f4d1efd051f6d80",
  )
}

///|
test "tokenize deterministic" {
  let a = @crypto.tokenize("k", "a@b.com", "h_", 12)
  let b = @crypto.tokenize("k", "a@b.com", "h_", 12)
  assert_eq(a, b)
  assert_true(a.has_prefix("h_"))
  assert_eq(a.length(), 14)
  assert_true(@crypto.tokenize("other", "a@b.com", "h_", 12) != a)
}

///|
test "sha256 hex" {
  // sha256("abc") 标准向量
  assert_eq(
    @crypto.sha256_hex("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "vault seal restore" {
  let v = @crypto.Vault::new("key")
  let t1 = v.seal("13800138000")
  let t2 = v.seal("13800138000")
  assert_eq(t1, t2)
  assert_eq(v.size(), 1)
  match v.restore(t1) {
    Some(s) => assert_eq(s, "13800138000")
    None => fail("restore failed")
  }
  match v.restore("[V:unknown]") {
    Some(_) => fail("unexpected restore")
    None => ()
  }
}
