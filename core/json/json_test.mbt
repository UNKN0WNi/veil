// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
// 有序 JSON AST 单测：保序、保数字原文、拒重复键、路径读写。

///|
test "json parse preserves order and big number" {
  match @json.parse_json("{\"b\":2,\"a\":1,\"big\":123456789012345678}") {
    Err(_) => fail("parse failed")
    Ok(v) => {
      let s = @json.write_json(v)
      assert_eq(s, "{\"b\":2,\"a\":1,\"big\":123456789012345678}")
    }
  }
}

///|
test "json parse rejects duplicate keys" {
  match @json.parse_json("{\"a\":1,\"a\":2}") {
    Err(_) => ()
    Ok(_) => fail("duplicate key should be rejected")
  }
}

///|
test "json get and set path" {
  match @json.parse_json("{\"user\":{\"email\":\"a@b.com\"}}") {
    Err(_) => fail("parse failed")
    Ok(v) => {
      match @json.get_path(v, "user.email") {
        Some(@json.Str(s)) => assert_eq(s, "a@b.com")
        _ => fail("get_path failed")
      }
      let v2 = @json.set_path(v, "user.email", @json.Str("h_xxx"))
      assert_eq(@json.write_json(v2), "{\"user\":{\"email\":\"h_xxx\"}}")
    }
  }
}

///|
test "json number text parses to double and int" {
  match @json.parse_json("{\"score\":0.75,\"exp\":1e-2,\"neg\":-3}") {
    Err(_) => fail("parse failed")
    Ok(v) => {
      assert_eq(v.get("score").unwrap().as_double(), Some(0.75))
      assert_true(v.get("exp").unwrap().as_double().unwrap() > 0.009)
      assert_eq(v.get("neg").unwrap().as_int(), Some(-3))
    }
  }
}
