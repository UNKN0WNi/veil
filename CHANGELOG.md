# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-11-16

### Added
- Multi-package MoonBit module (`core`, `crypto`, `cli`, `js`, `wasm`).
- Backend-agnostic `core` engine: 5 detector kinds, 7 operators, 10 validators,
  context scoring, deterministic overlap resolution, fail-closed policy.
- Dual-track JSON: text-span replacement (order/precision preserving) + minimal
  ordered AST (`Number(String)`, `Object(Array[...])`, duplicate-key rejection).
- Deterministic HMAC-SHA256 tokenization / in-memory reversible vault (`crypto/`).
- Built-in rulesets: `base` / `cn` / `secrets` / `headers` (all strict JSON).
- Language-neutral `spec/` (entities, validators, operators, JSON Schemas,
  cross-language golden cases + corpus).
- Four-end product entries; JS ESM export verified callable from Node.
- Scripts: `consistency.sh`, `rules-lint.sh`, `gen-spec.sh`, `build.sh`.
- Unit + golden tests: 19 tests pass on wasm / wasm-gc / js.

### Notes
- HMAC uses UTF-8 encoding and matches the cross-language standard vector.
- Native CLI target requires MSVC (`cl.exe`); verified via CI in environments with it.
- AES-GCM vault and stream chunk-invariance are planned for v1.

[0.1.0]: https://github.com/veil-lang/veil/releases/tag/v0.1.0
