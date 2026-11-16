// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
// JSON 路径匹配单测。

///|
test "path match" {
  assert_true(@json.path_match("user.email", "user.email"))
  assert_true(@json.path_match("user.*.phone", "user.contact.phone"))
  assert_true(@json.path_match("*.token", "api.token"))
  assert_false(@json.path_match("user.*.phone", "user.a.b.phone"))
}
