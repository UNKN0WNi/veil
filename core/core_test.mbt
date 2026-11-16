// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
// core 单元测试（计划书 §7.1 L1）。

///|
test "validator luhn" {
  assert_true(luhn("4111111111111111"))
  assert_true(luhn("79927398713"))
  assert_false(luhn("1234567812345678"))
}

///|
test "validator cn id" {
  assert_true(cn_id_checksum("11010519491231002X"))
  assert_false(cn_id_checksum("110105194912310021"))
}

///|
test "validator cn uscc" {
  // 统一社会信用代码样例
  assert_true(cn_uscc_checksum("91350211M000104820"))
}

///|
test "validator ipv4 ipv6" {
  assert_true(ipv4("192.168.1.1"))
  assert_false(ipv4("999.1.1.1"))
  assert_true(ipv6("2001:db8::1"))
  assert_false(ipv6("2001:::db8"))
}

///|
test "validator jwt isbn imei" {
  assert_true(jwt("eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.abcDEF123_"))
  assert_true(isbn("978-3-16-148410-0"))
  assert_true(imei("490154203237518"))
}

///|
test "path match" {
  assert_true(path_match("user.email", "user.email"))
  assert_true(path_match("user.*.phone", "user.contact.phone"))
  assert_true(path_match("*.token", "api.token"))
  assert_false(path_match("user.*.phone", "user.a.b.phone"))
}

///|
test "context delta boost and anti" {
  let conf = ContextConf::{
    words: ["手机"],
    anti_words: ["订单"],
    window: 20,
    boost: 0.45,
    penalty: 0.3,
    case_sensitive: false,
  }
  let d1 = context_delta("手机: 13800138000", 4, 15, conf)
  assert_true(d1 > 0.0)
  let d2 = context_delta("订单: 13800138000", 4, 15, conf)
  assert_true(d2 < 0.0)
}

///|
test "json parse preserves order and big number" {
  match parse_json("{\"b\":2,\"a\":1,\"big\":123456789012345678}") {
    Err(_) => fail("parse failed")
    Ok(v) => {
      let s = write_json(v)
      assert_eq(s, "{\"b\":2,\"a\":1,\"big\":123456789012345678}")
    }
  }
}

///|
test "json parse rejects duplicate keys" {
  match parse_json("{\"a\":1,\"a\":2}") {
    Err(_) => ()
    Ok(_) => fail("duplicate key should be rejected")
  }
}

///|
test "json get and set path" {
  match parse_json("{\"user\":{\"email\":\"a@b.com\"}}") {
    Err(_) => fail("parse failed")
    Ok(v) => {
      match get_path(v, "user.email") {
        Some(Str(s)) => assert_eq(s, "a@b.com")
        _ => fail("get_path failed")
      }
      let v2 = set_path(v, "user.email", Str("h_xxx"))
      assert_eq(write_json(v2), "{\"user\":{\"email\":\"h_xxx\"}}")
    }
  }
}

///|
test "operator mask hash tokenize determinism" {
  let op = Operator::default()
  op.type_ = "mask"
  op.keep_suffix = 4
  assert_eq(apply_operator(op, "13800138000", "", "*"), "*******8000")
  let h = Operator::default()
  h.type_ = "hash"
  h.length = 12
  h.prefix = "h_"
  let a = apply_operator(h, "a@b.com", "secret", "")
  let b = apply_operator(h, "a@b.com", "secret", "")
  assert_eq(a, b)
  assert_true(a.starts_with("h_"))
  let c = apply_operator(h, "a@b.com", "other", "")
  assert_true(a != c)
}

///|
test "hmac sha256 known vector" {
  // HMAC-SHA256(key="secret-key", msg="hello@example.com") — S0 三端黄金向量（UTF-8，跨语言标准）
  assert_eq(
    hmac_sha256_hex("secret-key", "hello@example.com"),
    "928bc0a4262ca7746556831aee52ee3edfb53b2efd95c57a8f4d1efd051f6d80",
  )
}

///|
test "ruleset load and engine redact email" {
  let rules =
    #|{"version":1,"rules_version":"test.1",
    #|"defaults":{"action":"redact","censor":"[REDACTED]","min_score":0.5},
    #|"detectors":[{"id":"email","description":"email","type":"pattern",
    #|"pattern":"[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}","score":0.9}],
    #|"operators":[{"id":"default","type":"redact"}],"formats":["plain"]}
  match load_ruleset(rules) {
    Err(e) => fail("load failed: \{e.errors}")
    Ok(rs) => {
      let opts = EngineOptions::default()
      let result = redact("mail me at a@b.com now", rs, opts)
      assert_eq(result.text, "mail me at [REDACTED] now")
      assert_eq(result.report.matched_count, 1)
      assert_eq(result.report.rules_version, "test.1")
    }
  }
}

///|
test "overlap resolution deterministic" {
  let d1 = Detected::{
    span: Span::{ start: 0, end: 5, },
    detector_id: "a",
    detector_order: 0,
    entity: "a",
    score: 0.9,
    matched_by: ["a"],
    operator_id: "",
    text: "aaaaa",
  }
  let d2 = Detected::{
    span: Span::{ start: 3, end: 8, },
    detector_id: "b",
    detector_order: 1,
    entity: "b",
    score: 0.5,
    matched_by: ["b"],
    operator_id: "",
    text: "bbbbb",
  }
  let resolved = resolve_overlaps([d1, d2])
  assert_eq(resolved.length(), 1)
  assert_eq(resolved[0].detector_id, "a")
}
