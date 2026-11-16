# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- English README (`README.en.md`) with a language switcher in both READMEs.
- Native CLI: `--text` / `--input` / `--output` / `--key-env` / `--dry-run` / `--json`,
  with UTF-8 file I/O through `moonbitlang/x/fs`.
- `scripts/msvc-env.sh`: locate MSVC + Windows SDK via `vswhere` and export
  `PATH` / `INCLUDE` / `LIB` for Git Bash, without `vcvars64.bat`.

### Fixed
- `pattern` detectors now apply their `validator` before scoring; this removes
  false positives such as `ac` in `contact` being treated as IPv6.
- `scripts/build.sh` no longer mislabels the ESM bundle as `veil.iife.js`.

### Changed
- `scripts/consistency.sh` now covers `wasm` / `wasm-gc` / `js` / `native`,
  including native CLI golden cases.
- `scripts/build.sh` copies the native binary to `dist/veil.exe` (or `dist/veil`).

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
- Native CLI target requires MSVC (`cl.exe`) or clang; local native build and
  tests were run with MSVC Build Tools 2022 + Windows SDK 10.0.26100.
- AES-GCM vault and stream chunk-invariance are planned for v1.

[0.1.0]: https://github.com/UNKN0WNi/veil/releases/tag/v0.1.0
