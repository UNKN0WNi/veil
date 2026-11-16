// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
// 校验器单测：每个校验器至少一个正例 + 一个反例。

///|
test "validator luhn" {
  assert_true(@validate.luhn("4111111111111111"))
  assert_true(@validate.luhn("79927398713"))
  assert_false(@validate.luhn("1234567812345678"))
}

///|
test "validator cn id" {
  assert_true(@validate.cn_id_checksum("11010519491231002X"))
  assert_false(@validate.cn_id_checksum("110105194912310021"))
}

///|
test "validator cn uscc" {
  // 统一社会信用代码样例
  assert_true(@validate.cn_uscc_checksum("91350211M000104820"))
}

///|
test "validator ipv4 ipv6" {
  assert_true(@validate.ipv4("192.168.1.1"))
  assert_false(@validate.ipv4("999.1.1.1"))
  assert_true(@validate.ipv6("2001:db8::1"))
  assert_false(@validate.ipv6("2001:::db8"))
}

///|
test "validator jwt isbn imei" {
  assert_true(
    @validate.jwt("eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.abcDEF123_"),
  )
  assert_true(@validate.isbn("978-3-16-148410-0"))
  assert_true(@validate.imei("490154203237518"))
}
