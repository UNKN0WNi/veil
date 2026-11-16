// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
// 参数解析单测：默认值、选项取值、布尔标志。

///|
test "parse args with text and flags" {
  let a = @app.parse_args([
    "veil", "--text", "hi", "--rules", "r.json", "--json", "--dry-run",
  ])
  assert_eq(a.text, Some("hi"))
  assert_eq(a.rules, Some("r.json"))
  assert_eq(a.key_env, "VEIL_KEY")
  assert_true(a.json)
  assert_true(a.dry_run)
  assert_false(a.version)
}

///|
test "parse args with input output and key env" {
  let a = @app.parse_args([
    "veil", "--input", "in.log", "--output", "out.log", "--key-env", "MY_KEY",
  ])
  assert_eq(a.input, Some("in.log"))
  assert_eq(a.output, Some("out.log"))
  assert_eq(a.key_env, "MY_KEY")
  assert_false(a.json)
}
