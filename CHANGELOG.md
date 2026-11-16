# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Removed
- Internal planning documents (`PLAN.md`, `IMPLEMENTATION_PLAN.md`) and the
  competition proposal are no longer part of the repository; references to
  plan sections were stripped from source comments and scripts.

### Added
- Rule files now document themselves in-band: `$schema` (editor completion and
  hover hints), `_comment` on the top level, `defaults`, `operators[]` and
  `policy`, and `_how_to_customize` with task-oriented hints. All three keys
  are ignored by the loader.
- `spec/schemas/ruleset.schema.json` and `testcase.schema.json` now carry a
  Chinese `description` on every property, so editing a rule file shows what
  each field means and what to change.
- `rules/README.md` rewritten as a customisation guide: a 30-second minimal
  rule set, field reference tables, recipes for false positives / recall /
  output form / whitelists, regex-dialect pitfalls, and an English field
  reference appendix.
- `moon.mod` and `js/package.json` explain each field in plain language
  (`js/package.json` uses the npm `//`-prefixed key convention).
- `core` is now split into dependency-ordered subpackages: `json`, `text`,
  `rules`, `detect`, `ops`, `validate`, `structure`, with `veil/core` acting as
  a facade that re-exports the public API unchanged.
- `JsonValue` accessors (`get` / `as_str` / `as_bool` / `as_array` / `as_double`
  / `as_int`); rule loading now uses the ordered AST instead of `core/json`.
- `cli/app` package with argument parsing, file I/O and output formatting, plus
  unit tests for `parse_args`.
- English README (`README.en.md`) with a language switcher in both READMEs.
- Native CLI: `--text` / `--input` / `--output` / `--key-env` / `--dry-run` / `--json`,
  with UTF-8 file I/O through `moonbitlang/x/fs`.
- `scripts/msvc-env.sh`: locate MSVC + Windows SDK via `vswhere` and export
  `PATH` / `INCLUDE` / `LIB` for Git Bash, without `vcvars64.bat`.
- `scripts/toolchain-env.sh`: locate the MoonBit toolchain when `moon` is not on
  `PATH` (honours `MOON` / `MOON_BIN_DIR`, probes the official install dir and
  managed toolchain directories); `build.sh` and `consistency.sh` source it.
- GitHub Actions workflow (`.github/workflows/ci.yml`): a `fmt` job
  (`moon fmt --check`, `moon check --deny-warn`, `.mbti` drift, rule lint, spec
  index freshness), a `test` job matrixed over `wasm` / `wasm-gc` / `js` /
  `native`, and a `consistency` job that runs the full cross-backend check and
  uploads release artifacts.

### Fixed
- `pattern` detectors now apply their `validator` before scoring; this removes
  false positives such as `ac` in `contact` being treated as IPv6.
- `scripts/build.sh` no longer mislabels the ESM bundle as `veil.iife.js`.
- `scripts/consistency.sh` reports the real compiler error instead of a bare
  `FAIL` line, and no longer swallows failing `moon test` runs (`pipefail` plus
  `|| true` hid the exit status). Native is skipped only when neither
  `cl.exe` / `clang-cl.exe` nor `clang` is available, so Linux/macOS run it too.

### Changed
- `scripts/consistency.sh` now covers `wasm` / `wasm-gc` / `js` / `native`,
  including native CLI golden cases.
- `scripts/build.sh` copies the native binary to `dist/veil.exe` (or `dist/veil`).
- Tests live next to the code they cover; `core/core_test.mbt` keeps only the
  end-to-end cases.
- Dead code removed: `from_core_json` and the `core/json` dependency of `core`.
- Deprecated APIs replaced (`starts_with` → `has_prefix`, `Int::from_int` →
  `unsafe_to_char`, `is_none()` → `is None`); `moon check` is now warning-free.

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
