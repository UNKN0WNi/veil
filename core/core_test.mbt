// Copyright 2026 veil contributors
// SPDX-License-Identifier: Apache-2.0
// core 集成测试（计划书 §7.1 L2）：规则 JSON → IR → 检测 → 消解 → 算子 → 文本。
// 各子包的单元测试放在对应包内（validate / json / text / detect / ops）。

///|
test "pattern detector applies validator" {
  let rules_json = "{\"version\":1,\"rules_version\":\"t.1\",\"defaults\":{\"action\":\"redact\",\"censor\":\"[REDACTED]\",\"min_score\":0.5},\"detectors\":[{\"id\":\"ipv6\",\"description\":\"ipv6\",\"type\":\"pattern\",\"pattern\":\"[0-9A-Fa-f:]{2,39}\",\"validator\":\"ipv6\",\"score\":0.6}],\"operators\":[{\"id\":\"default\",\"type\":\"redact\"}]}"
  let rs = match @core.load_ruleset(rules_json) {
    Ok(v) => v
    Err(_) => fail("load failed")
  }
  // "ac" 形似 IPv6 片段，但 validator 必须把它过滤掉。
  let false_positive = @core.redact(
    "contact ac now",
    rs,
    @core.EngineOptions::default(),
  )
  assert_eq(false_positive.text, "contact ac now")
  assert_eq(false_positive.report.matched_count, 0)
  // 合法 IPv6 仍然命中。
  let real = @core.redact(
    "addr 2001:db8::1",
    rs,
    @core.EngineOptions::default(),
  )
  assert_eq(real.text, "addr [REDACTED]")
  assert_eq(real.report.matched_count, 1)
}

///|
test "ruleset load and engine redact email" {
  let rules =
    #|{"version":1,"rules_version":"test.1",
    #|"defaults":{"action":"redact","censor":"[REDACTED]","min_score":0.5},
    #|"detectors":[{"id":"email","description":"email","type":"pattern",
    #|"pattern":"[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}","score":0.9}],
    #|"operators":[{"id":"default","type":"redact"}],"formats":["plain"]}
  match @core.load_ruleset(rules) {
    Err(e) => fail("load failed: " + e.errors.join(","))
    Ok(rs) => {
      let opts = @core.EngineOptions::default()
      let result = @core.redact("mail me at a@b.com now", rs, opts)
      assert_eq(result.text, "mail me at [REDACTED] now")
      assert_eq(result.report.matched_count, 1)
      assert_eq(result.report.rules_version, "test.1")
    }
  }
}
