// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
// 算子单测：确定性、前缀、密钥敏感性。

///|
test "operator mask hash tokenize determinism" {
  let op = @ops.Operator::default()
  op.type_ = "mask"
  op.keep_suffix = 4
  assert_eq(@ops.apply_operator(op, "13800138000", "", "*"), "*******8000")
  let h = @ops.Operator::default()
  h.type_ = "hash"
  h.length = 12
  h.prefix = "h_"
  let a = @ops.apply_operator(h, "a@b.com", "secret", "")
  let b = @ops.apply_operator(h, "a@b.com", "secret", "")
  assert_eq(a, b)
  assert_true(a.has_prefix("h_"))
  let c = @ops.apply_operator(h, "a@b.com", "other", "")
  assert_true(a != c)
}

///|
test "hmac sha256 known vector" {
  // HMAC-SHA256(key="secret-key", msg="hello@example.com") — 四端黄金向量（UTF-8，跨语言标准）
  assert_eq(
    @ops.hmac_sha256_hex("secret-key", "hello@example.com"),
    "928bc0a4262ca7746556831aee52ee3edfb53b2efd95c57a8f4d1efd051f6d80",
  )
}
