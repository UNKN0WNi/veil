// veil — 跨端 PII 与日志脱敏内核
// 一份声明式 JSON 规则，多端一致（wasm / wasm-gc / js / native）
name = "veil"

version = "0.1.0"

license = "Apache-2.0"

description = "Cross-platform PII & log redaction kernel: one declarative JSON ruleset, byte-identical across backends"

repository = "https://github.com/UNKN0WNi/veil"

keywords = [ "pii", "redaction", "masking", "privacy", "log-scrubbing" ]

readme = "README.md"

// crypto 包使用 x/crypto 的 SHA-256 与 HMAC（四后端字节一致，S0 已验证）。
// core 包仅依赖 moonbitlang/core，保持后端无关。
import {
  "moonbitlang/x@0.5.7",
}
