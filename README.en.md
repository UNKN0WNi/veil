<div align="center">

# veil

**Turn PII and credentials in logs, prompts and HTTP traffic into safe placeholders.**

One MoonBit kernel for JS / WASM / WASM-GC / Native;<br>
one declarative JSON rule set, byte-identical across backends.

[![CI](https://github.com/UNKN0WNi/veil/actions/workflows/ci.yml/badge.svg)](https://github.com/UNKN0WNi/veil/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20261104-orange.svg)](https://www.moonbitlang.com/)
[![Backends](https://img.shields.io/badge/backends-js%20%7C%20wasm%20%7C%20wasm--gc%20%7C%20native-green.svg)](#artifacts-and-entry-points)
[![Tests](https://img.shields.io/badge/tests-23%20x%204%20backends-brightgreen.svg)](#tests-and-quality)

[简体中文](./README.md) · **English**

[Quick start](#quick-start) · [Usage](#usage) · [Rule format](#rule-format) · [Output and audit](#output-and-audit) · [Architecture](#architecture) · [Tests and quality](#tests-and-quality) · [Known limitations](#known-limitations)

</div>

---

## Why veil

- **One source, many targets.** `core/` has no `target` branches; JS, WASM, WASM-GC and Native compile the same detection, scoring, resolution and operator code. There is no second implementation of rule loading, execution order or output format.
- **Rules are data, not code.** Detectors, operators, context words and policy all live in strict JSON; `spec/` describes entities, validators and golden cases in language-neutral JSON. Reimplement it in another language and the spec still holds.
- **Deterministic output, faithful input.** The default text track only replaces ranges in the original string. It never rewrites JSON or log formatting: key order, whitespace and number literals stay untouched. Same input, same rules, same key, same bytes.
- **Validate before redacting.** Ten validators turn "looks like" into "checks out": Luhn, Chinese ID card, bank card and USCC, ISBN, IMEI, IPv4/IPv6, Base64, JWT. Candidates that fail validation are dropped outright.
- **No bare hashing of low-entropy values.** Emails and phone numbers go through HMAC-SHA256 (UTF-8) by default, so a rainbow table cannot reverse them; keys come from the caller or an environment variable, never from the rule set.
- **No model, no network.** No NLP models, no outbound requests. The kernel runs in browsers, Node, edge workers and native binaries.

## Quick start

You need the **MoonBit toolchain** (verified on `moon 0.1.20261104`) and **Node.js ≥ 18** to run the JS artifact.

```bash
git clone https://github.com/UNKN0WNi/veil.git
cd veil

moon install
moon build --target js
moon test --target js
```

Run a real redaction:

```js
// demo.mjs
import { redact_text } from './_build/js/debug/build/js/js.js';
import fs from 'node:fs';

const rules = fs.readFileSync('rules/base.json', 'utf8');
console.log(redact_text('user alice@example.com login from 10.2.3.4', rules, 'demo-key'));
```

```bash
node demo.mjs
# {"text":"user [REDACTED] login from [REDACTED]","count":2}
```

`redact_text` returns a **single-line JSON string**: `text` is the redacted output, `count` is the number of matches. A `count` of `-1` means the rule set failed to load — callers must check it instead of treating an empty `text` as success.

Build all four artifacts (on Windows the script imports the MSVC environment automatically):

```bash
bash scripts/build.sh
```

## Usage

### Artifacts and entry points

| Artifact | Backend | Entry point | Status |
| --- | --- | --- | --- |
| `veil.js` + `veil.d.ts` | JS (ESM) | Node / bundlers / browsers | verified |
| `*.wasm` | WASM (MVP) | edge / any wasm runtime | verified |
| `*.wasm` | WASM-GC | modern browsers / edge | verified |
| `veil` / `veil.exe` | Native | CLI / server side | verified (Windows MSVC 2022) |

### Node / ESM

```bash
moon build --target js
# output: _build/js/debug/build/js/js.js (ESM)
```

```js
import {
  version,
  load_ruleset_status,
  redact_text,
  tokenize,
  hmac_sha256_hex,
} from './_build/js/debug/build/js/js.js';

const rules = fs.readFileSync('rules/base.json', 'utf8');

load_ruleset_status(rules);                              // "" = ok; otherwise per-rule errors
redact_text(input, rules, process.env.VEIL_KEY ?? '');   // '{"text":...,"count":...}'
tokenize('demo-key', 'alice@example.com', 'h_', 12);     // 'h_d0391c057f4e'
hmac_sha256_hex('secret-key', 'hello@example.com');      // '928bc0a4...051f6d80'
```

`js/veil.d.ts` ships TypeScript declarations; `js/package.json` is the npm entry (not published to the registry yet).

### Browser / edge

The same ESM artifact loads directly in a browser (serve it over a static server; `file://` is blocked by CORS):

```html
<script type="module">
  import { redact_text } from './veil.js';
  const rules = await (await fetch('./rules/base.json')).text();
  console.log(redact_text('mail a@b.com', rules, ''));
</script>
```

WASM / WASM-GC artifacts:

```bash
moon build --target wasm
moon build --target wasm-gc
# output: _build/wasm*/debug/build/**/*.wasm
```

Rules are passed as a string, so no filesystem is required; the entry points export `version`, `redact_text` and `tokenize`. On the WASM side you supply the host string/memory glue, or run `moon run --target wasm` as the minimal form.

### MoonBit

```moonbit
import { "veil/core" @core }

let rs = match @core.load_ruleset(rules_json) {
  Ok(v) => v
  Err(e) => {
    println(e.errors)
    return
  }
}

let result = @core.redact(
  text,
  rs,
  @core.EngineOptions::{ key: key, enable_policy: false },
)

println(result.text)                  // redacted text
println(result.report.matched_count)  // number of matches
```

### CLI (native)

Windows needs MSVC (the "Desktop development with C++" workload from Build Tools); Unix needs clang. `scripts/build.sh` builds the binary and copies it to `dist/veil.exe` (`dist/veil` on Unix).

```bash
bash scripts/build.sh

./dist/veil.exe --text "user alice@example.com login from 10.2.3.4" --rules rules/base.json
# user [REDACTED] login from [REDACTED]

./dist/veil.exe --text "user alice@example.com login from 10.2.3.4" --rules rules/base.json --json
# {"text":"user [REDACTED] login from [REDACTED]","count":2}

./dist/veil.exe --input in.log --rules rules/base.json --output out.log
./dist/veil.exe --text "user alice@example.com" --rules rules/base.json --dry-run
```

| Flag | Meaning |
| --- | --- |
| `--text <TEXT>` | Redact an inline string |
| `--input <FILE>` | Read input from a file |
| `--rules <FILE>` | Rule set JSON (required) |
| `--output <FILE>` | Write to a file; stdout by default |
| `--key-env <NAME>` | Read the HMAC key from an env var, `VEIL_KEY` by default |
| `--dry-run` | Print the audit report only, never the input |
| `--json` | Emit `{"text":...,"count":...}` for scripting |
| `--version` / `--help` | Version / help |

Sample `--dry-run` output:

```text
rules_version=2026.11.1
matched=2
by_entity:
  email=1
  ipv4=1
by_operator:
  redact=2
spans:
  email 5-22 operator=redact detector=email
  ipv4 34-42 operator=redact detector=ipv4
```

Under Windows Git Bash, `scripts/build.sh` imports the MSVC environment automatically; you can also run `source scripts/msvc-env.sh` by hand. When `moon` is not on the default PATH, the scripts locate the toolchain through `scripts/toolchain-env.sh` (override with `MOON=/path/to/moon`). When a rule file is unreadable, a rule set is invalid or the input is missing, the CLI exits with code `2`.

## Rule format

A rule set is strict JSON (schema: [`spec/schemas/ruleset.schema.json`](./spec/schemas/ruleset.schema.json)):

```json
{
  "version": 1,
  "rules_version": "demo.1",
  "defaults": { "action": "redact", "censor": "[REDACTED]", "min_score": 0.5 },
  "detectors": [
    {
      "id": "email",
      "description": "Standard email address. False positives: noreply@, example.com.",
      "type": "pattern",
      "pattern": "[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}",
      "score": 0.9
    }
  ],
  "operators": [{ "id": "default", "type": "redact" }]
}
```

**Top-level fields:**

| Field | Meaning |
| --- | --- |
| `version` | Rule format version, currently `1` |
| `rules_version` | Content version, copied into the audit report for traceability |
| `defaults` | Defaults for `action` / `censor` / `min_score` |
| `detectors` | Detector array; **array order participates in overlap resolution** |
| `operators` | Operator array, referenced by detectors via `id` |
| `policy` | Structural-track allowlist: `mode` / `allow_paths` / `ignore_paths` |
| `formats` | Declared input shapes: `json` / `logfmt` / `plain` / `http_headers` |
| `includes` | Composition metadata (the loader does not merge it automatically) |

**Detector types:**

| `type` | Role | Key fields |
| --- | --- | --- |
| `pattern` | Regex scan | `pattern`, `score`, `validator`, `context` |
| `dictionary` | Term substring match | `terms`, `case_sensitive` |
| `checksum` | Checksum-verified candidate | `pattern` + `validator` |
| `composite` | Combine detectors | `detectors`, `targets` |
| `field` | Field path (structural track) | `targets`; not consumed by the v0.1 text track |

**Operators:**

| `type` | Output | Notes |
| --- | --- | --- |
| `redact` | `[REDACTED]` | Whole-span replacement, the default |
| `replace` | Custom text | `replacement` |
| `mask` | `a***@***` | `keep.prefix` / `keep.suffix` / `fill` |
| `hash` | `h_ab12...` | `algo`: `hmac_sha256` (default) or `sha256`; `prefix` / `length` |
| `tokenize` | `h_ab12...` | HMAC(key, `"tok|" + value`), a deterministic pseudonym |
| `encrypt` | `...|rev` | v0.1 placeholder token; the AES-GCM vault is on the roadmap |
| `keep` | Original value | Explicit pass-through |

**Validators:** `luhn`, `cn_id_checksum`, `cn_bank_card_checksum`, `cn_uscc_checksum`, `isbn`, `imei`, `ipv4`, `ipv6`, `base64`, `jwt`.

**Context scoring:** a hit in `context.words` adds `boost`, a hit in `context.anti_words` subtracts `penalty`, and the window is controlled by `window` (24 characters by default). Multiple words around one match count once, which keeps results deterministic.

**Regex dialect (important):** rule patterns use the built-in MoonBit `lexmatch` subset. `\d`, `\w`, `\s` and `\b` are unsupported — use POSIX classes such as `[[:digit:]]`; a literal `-` inside a character class is written `\\-`; lookahead and backreferences are not available. `scripts/rules-lint.sh` checks this for you.

**Errors are fatal:** loading performs schema and semantic validation (duplicate ids, references to missing detectors or operators, invalid regex, missing `description`, and so on). Any invalid rule fails the whole rule set instead of silently skipping it. Semantics depend only on array order, never on object key order.

**How to customise:** rule files carry their docs in `$schema` / `_comment` / `_how_to_customize` (all ignored by the loader), and per-field explanations live in the schema `description`, so editing a rule file in VS Code gives completion and inline hints. Field-by-field reference and recipes (cut false positives, raise recall, switch output form, whitelist paths) are in [`rules/README.md`](./rules/README.md).

## Output and audit

The JS entry point returns single-line JSON:

```json
{"text":"user [REDACTED] login from [REDACTED]","count":2}
```

Inside MoonBit you get a `RedactResult`:

| Field | Content |
| --- | --- |
| `text` | Redacted text |
| `report.rules_version` | Rule version |
| `report.matched_count` | Number of matches |
| `report.by_entity` | Matches per entity type |
| `report.by_operator` | Matches per operator |
| `report.spans` | `entity` / `start` / `end` / `operator` / `detector` per match |

Audit records **never contain the original text** — only types, offsets, operators and the rule version.

The structural track exposes two lower-level APIs: `redact_json_policy(text, ruleset)` for fail-closed allowlist filtering, and `redact_json_fields(text, ruleset, replacements)` for whole-field replacement by path. Neither is wired into the default `redact` path; callers opt in explicitly.

## Architecture

```text
input text / JSON / log line
└─► load_ruleset      JSON → IR, schema + semantic validation, all-or-nothing
    └─► detect_all    pattern / dictionary / checksum / composite
        └─► scoring   context boost / penalty · validator
            └─► resolve   score → declaration order → span length → start offset
                └─► operator   redact / replace / mask / hash / tokenize / encrypt / keep
                    └─► text-track range replacement
                        └─► RedactResult { text, report }
```

| Module | Responsibility |
| --- | --- |
| `core/` | Facade: engine orchestration (detect → resolve → operator → report) plus re-exports of the subpackages |
| `core/json/` | Ordered JSON AST, parser, serializer, JSON paths |
| `core/text/` | `Span` / `Detected` / deterministic overlap resolution |
| `core/rules/` | Rule IR, JSON → IR loading and semantic validation, context window config |
| `core/detect/` | Four detection strategies (pattern / dictionary / checksum / composite) plus context scoring |
| `core/ops/` | The seven operators |
| `core/validate/` | The ten validators |
| `core/structure/` | Format detection and the JSON structural track |
| `crypto/` | HMAC-SHA256, SHA-256, deterministic tokens, in-process Vault |
| `cli/` `js/` `wasm/` | Three entry packages; `cli/app` holds the testable CLI logic, `cli/` keeps only `main` |
| `rules/` | Four built-in rule sets: base / cn / secrets / headers |
| `spec/` | Language-neutral spec: entities, validators, operators, JSON Schema, golden cases and corpus |
| `scripts/` | Consistency, rule lint, spec generation, artifact build, toolchain and MSVC environment discovery |
| `.github/workflows/` | CI: format and warning gates, four-target matrix, cross-backend consistency |

Dependencies flow one way, with no cycles:

```text
json / text / validate / ops        (leaves, independent of each other)
        └──► rules ──► detect ──┐
                    structure ──┼──► core (orchestration + facade)
                                ┘
cli / js / wasm depend only on the `core` facade
```

No package under `core/*` declares a target or touches platform APIs; every backend difference stays in the entry packages. Callers import `veil/core` only — the subpackage split is invisible in the API.

## Consistency guarantees

"Identical across backends" is a constraint, not a hope:

- `core/` and `crypto/` contain no `target` branches; JS / WASM / WASM-GC / Native compile the same source.
- Detectors run in rule array order; overlap resolution uses a four-level tie-break (score → declaration order → length → start offset) and never relies on hash iteration.
- The text track only replaces inside the original string and never re-serializes the output, so ordering, whitespace and number literals survive untouched.
- HMAC and tokens are always UTF-8; the golden vector is `HMAC-SHA256("secret-key","hello@example.com") = 928bc0a4...051f6d80`.
- Measured on 2026-11-16: **23 tests × wasm / wasm-gc / js / native all pass**; the 6 golden cases are byte-identical on both the JS ESM artifact and the native CLI. The same contract is reproduced on Windows (MSVC) and on GitHub Actions Ubuntu (clang 21).

```bash
bash scripts/consistency.sh
```

## Tests and quality

```bash
moon test --target js          # 23 tests
moon test --target wasm
moon test --target wasm-gc
moon test --target native
bash scripts/rules-lint.sh     # rule set syntax and banned-regex checks
bash scripts/consistency.sh    # four-target check / test / build + golden cases + HMAC vector
bash scripts/build.sh          # build JS / WASM / WASM-GC / Native into dist/
```

| Layer | Content |
| --- | --- |
| L1 unit | Validators, paths, context, operators, JSON parse/serialize, overlap resolution |
| L2 integration | Rule JSON → IR → end-to-end execution |
| L3 cross-backend | The same cases compiled and run on wasm / wasm-gc / js / native |
| L4 golden | Byte-for-byte comparison against `spec/test-cases/cases.json` (JS ESM + native CLI) plus the HMAC standard vector |

CI ([`.github/workflows/ci.yml`](./.github/workflows/ci.yml)) turns that contract into three jobs:

| Job | Coverage |
| --- | --- |
| `fmt` | `moon fmt --check`, `moon check --deny-warn`, no drift in generated `.mbti`, rule-set lint, `spec/rules-index.json` in sync with `rules/` |
| `test` | `wasm` / `wasm-gc` / `js` / `native` matrix: check + test + build |
| `consistency` | Full `scripts/consistency.sh` run, 6 golden cases, HMAC vector, plus release artifacts uploaded |

## API reference

**MoonBit (`veil/core`):**

| Function | Returns | Notes |
| --- | --- | --- |
| `load_ruleset(json)` | `Result[Ruleset, RuleLoadError]` | Strict JSON → rule IR, with semantic validation |
| `redact(text, ruleset, options)` | `RedactResult` | Main text-track entry point |
| `redact_json_policy(text, ruleset)` | `Result[String, JsonParseError]` | Structural-track fail-closed allowlist filter |
| `redact_json_fields(text, ruleset, replacements)` | `Result[String, JsonParseError]` | Structural-track whole-field replacement by path |
| `Ruleset::empty()` | `Ruleset` | Empty rule set, handy for tests |

**JS ESM:**

| Function | Returns | Notes |
| --- | --- | --- |
| `version()` | `String` | `0.1.0` |
| `load_ruleset_status(rules)` | `String` | Empty string means ok; otherwise per-rule errors |
| `redact_text(input, rules, key)` | `String` | `{"text":...,"count":...}`; `count:-1` on failure |
| `tokenize(key, value, prefix, length)` | `String` | Deterministic HMAC token |
| `hmac_sha256_hex(key, message)` | `String` | UTF-8 HMAC-SHA256 hex |

**WASM / WASM-GC:** `version`, `redact_text`, `tokenize`.

## Layout

```text
veil/
├── core/               facade: engine orchestration + public re-exports
│   ├── json/           ordered JSON AST / parser / serializer / paths
│   ├── text/           Span / Detected / overlap resolution
│   ├── rules/          rule IR and loading
│   ├── detect/         detection strategies + context scoring
│   ├── ops/            the seven operators
│   ├── validate/       the ten validators
│   └── structure/      format detection + JSON structural track
├── crypto/             HMAC-SHA256, tokens, in-process Vault
├── cli/                CLI entry (main)
│   └── app/            argument parsing / file I/O / output formatting (with tests)
├── js/ wasm/           the two runtime entry points
├── rules/              base / cn / secrets / headers
├── spec/               entities / validators / operators / schemas / test-cases
├── scripts/            consistency / rules-lint / gen-spec / build / msvc-env / toolchain-env
├── .github/workflows/  CI: fmt + four-target matrix + consistency
├── moon.mod            module definition
├── README.md           Chinese version
├── README.en.md        English version
├── CHANGELOG.md
└── LICENSE
```

## Known limitations

- **No NLP or ML entity recognition.** Names and addresses in free text rely on `dictionary`, context words and field paths, so recall is not guaranteed.
- **`field` detectors and the structural track are not on the default path.** v0.1 `redact` runs the text track only; field-level work requires calling `redact_json_policy` / `redact_json_fields`, and `rules/headers.json` field rules do not apply automatically yet.
- **`encrypt` is a placeholder.** It returns a deterministic HMAC token, not AES-GCM ciphertext; `crypto/Vault` is an in-process map and cannot be restored across processes.
- **`includes` is not merged automatically.** It is declarative metadata; load the rule files you need and merge their detectors in the caller.
- **Regex is a lexmatch subset.** No `\d` `\w` `\s` `\b`, lookahead or backreferences; run `rules-lint.sh` before swapping rule sets.
- **WASM entry points handle errors weakly.** `redact_text` returns the input unchanged when the rule set fails to load; validate rules in JS or at build time, or handle `Result` explicitly at the MoonBit layer.
- **Not published yet.** Neither mooncakes nor the npm registry has a release; package config and type declarations are ready.
- **Native builds depend on the local toolchain.** Windows needs MSVC Build Tools (C++ workload + Windows SDK), Unix needs clang; no prebuilt binaries are committed.

## Docs and examples

| Document | Content |
| --- | --- |
| [`rules/README.md`](./rules/README.md) | **Customisation guide**: field reference, common tweaks, false positives, regex dialect |
| [`spec/schemas/ruleset.schema.json`](./spec/schemas/ruleset.schema.json) | Rule set JSON Schema |
| [`spec/test-cases/cases.json`](./spec/test-cases/cases.json) | Cross-language golden cases |
| [`CHANGELOG.md`](./CHANGELOG.md) | Release history |

## Contributing

1. A new detector, operator or validator must ship with its `spec/` entry, test cases and a `description`.
2. Rule regexes may only use the shared lexmatch subset; `bash scripts/rules-lint.sh` must pass.
3. Built-in rule sets must not depend on custom extensions; run `bash scripts/consistency.sh` after touching the kernel.
4. Format with `moon fmt`; `core/` must not import platform-specific dependencies.

## License

Apache-2.0, see [LICENSE](./LICENSE).
