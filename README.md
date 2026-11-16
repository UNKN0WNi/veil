<div align="center">

# veil

**把日志、prompt、HTTP 流量里的 PII 与凭据，变成安全的占位符。**

一份 MoonBit 内核面向 JS / WASM / WASM-GC / Native；<br>
一份声明式 JSON 规则，跨后端逐字节一致。

[![CI](https://github.com/UNKN0WNi/veil/actions/workflows/ci.yml/badge.svg)](https://github.com/UNKN0WNi/veil/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
[![MoonBit](https://img.shields.io/badge/MoonBit-0.1.20261104-orange.svg)](https://www.moonbitlang.com/)
[![Backends](https://img.shields.io/badge/backends-js%20%7C%20wasm%20%7C%20wasm--gc%20%7C%20native-green.svg)](#产物与入口)
[![Tests](https://img.shields.io/badge/tests-23%20x%204%20backends-brightgreen.svg)](#测试与质量)

**简体中文** · [English](./README.en.md)

[快速开始](#快速开始) · [用法](#用法) · [规则格式](#规则格式) · [输出与审计](#输出与审计) · [架构](#架构) · [测试与质量](#测试与质量) · [已知限制](#已知限制)

</div>

---

## 为什么用 veil

- **一份源码，多端同构。** `core/` 不写 target 分支；JS、WASM、WASM-GC、Native 编译同一份检测、打分、消解与算子代码。规则加载、执行顺序、输出格式没有第二套实现。
- **规则是数据，不是代码。** 检测器、算子、上下文词、策略全部写在严格 JSON 里；`spec/` 用语言无关的 JSON 描述实体、校验器与黄金用例。换语言实现，规范不变。
- **输出确定，原文保真。** 默认走文本轨：只在原始字符串上做区间替换，不改写 JSON / 日志格式，键顺序、空白、数字原文都不动。同样的输入、规则与密钥，永远得到同样的字节。
- **先校验，再脱敏。** 10 个校验器把"长得像"变成"算得过"：Luhn、中国身份证 / 银行卡 / 统一社会信用代码、ISBN、IMEI、IPv4 / IPv6、Base64、JWT。校验不通过的候选直接丢弃。
- **低熵值不裸哈希。** 邮箱、手机号这类低熵值默认用 HMAC-SHA256（UTF-8），避免裸 SHA-256 被彩虹表反查；密钥只从调用方或环境变量注入，不写进规则。
- **零模型、零网络。** 不依赖 NLP 模型、不发起网络请求，内核可直接跑在浏览器、Node、边缘 Worker 与 native 二进制里。

## 快速开始

需要 **MoonBit 工具链**（本项目在 `moon 0.1.20261104` 验证）与 **Node.js ≥ 18**（跑 JS 产物）。

```bash
git clone https://github.com/UNKN0WNi/veil.git
cd veil

moon install
moon build --target js
moon test --target js
```

跑一次真实脱敏：

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

`redact_text` 返回**单行 JSON 字符串**：`text` 是脱敏结果，`count` 是命中数。`count` 为 `-1` 表示规则加载失败——调用方必须检查，不要把空 `text` 当成功。

构建全部四端产物（Windows 下脚本会自动导入 MSVC 环境）：

```bash
bash scripts/build.sh
```

## 用法

### 产物与入口

| 产物 | 后端 | 入口 | 状态 |
| --- | --- | --- | --- |
| `veil.js` + `veil.d.ts` | JS (ESM) | Node / 打包器 / 浏览器 | 已验证 |
| `*.wasm` | WASM (MVP) | 边缘 / 任意 wasm 运行时 | 已验证 |
| `*.wasm` | WASM-GC | 现代浏览器 / 边缘 | 已验证 |
| `veil` / `veil.exe` | Native | CLI / 服务端 | 已验证（Windows MSVC 2022） |

### Node / ESM

```bash
moon build --target js
# 产物：_build/js/debug/build/js/js.js（ESM）
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

load_ruleset_status(rules);                              // "" = 通过；否则是逐条错误
redact_text(input, rules, process.env.VEIL_KEY ?? '');   // '{"text":...,"count":...}'
tokenize('demo-key', 'alice@example.com', 'h_', 12);     // 'h_d0391c057f4e'
hmac_sha256_hex('secret-key', 'hello@example.com');      // '928bc0a4...051f6d80'
```

`js/veil.d.ts` 提供 TypeScript 声明；`js/package.json` 是 npm 打包入口（尚未发布到 registry）。

### 浏览器 / 边缘

同一份 ESM 产物可被浏览器直接加载（用静态服务器打开，`file://` 会被 CORS 拦截）：

```html
<script type="module">
  import { redact_text } from './veil.js';
  const rules = await (await fetch('./rules/base.json')).text();
  console.log(redact_text('mail a@b.com', rules, ''));
</script>
```

WASM / WASM-GC 产物：

```bash
moon build --target wasm
moon build --target wasm-gc
# 产物：_build/wasm*/debug/build/**/*.wasm
```

规则以字符串传入，不依赖文件系统；入口导出 `version`、`redact_text`、`tokenize`。WASM 侧需要宿主提供字符串 / 内存胶水，或直接用 `moon run --target wasm` 作为最小运行形态。

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

println(result.text)                  // 脱敏后的文本
println(result.report.matched_count)  // 命中数
```

### CLI（native）

Windows 需要 MSVC（Build Tools 的“使用 C++ 的桌面开发”工作负载）；Unix 需要 clang。`scripts/build.sh` 会构建并把可执行文件复制到 `dist/veil.exe`（Unix 为 `dist/veil`）。

```bash
bash scripts/build.sh

./dist/veil.exe --text "user alice@example.com login from 10.2.3.4" --rules rules/base.json
# user [REDACTED] login from [REDACTED]

./dist/veil.exe --text "user alice@example.com login from 10.2.3.4" --rules rules/base.json --json
# {"text":"user [REDACTED] login from [REDACTED]","count":2}

./dist/veil.exe --input in.log --rules rules/base.json --output out.log
./dist/veil.exe --text "user alice@example.com" --rules rules/base.json --dry-run
```

| 参数 | 说明 |
| --- | --- |
| `--text <TEXT>` | 直接脱敏一段内联文本 |
| `--input <FILE>` | 从文件读取输入 |
| `--rules <FILE>` | 规则集 JSON（必填） |
| `--output <FILE>` | 写入文件；默认 stdout |
| `--key-env <NAME>` | 从环境变量读 HMAC 密钥，默认 `VEIL_KEY` |
| `--dry-run` | 只输出审计报告，不含原文 |
| `--json` | 输出 `{"text":...,"count":...}`，便于脚本消费 |
| `--version` / `--help` | 版本 / 帮助 |

`--dry-run` 输出示例：

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

Windows Git Bash 下 `scripts/build.sh` 会自动导入 MSVC 环境；也可手动执行 `source scripts/msvc-env.sh`。`moon` 不在默认 PATH 时，脚本会通过 `scripts/toolchain-env.sh` 自动定位工具链（也可用 `MOON=/path/to/moon` 指定）。规则文件读取失败、规则非法或输入缺失时，CLI 以退出码 `2` 结束。

## 规则格式

一份规则集是严格 JSON（schema 见 [`spec/schemas/ruleset.schema.json`](./spec/schemas/ruleset.schema.json)）：

```json
{
  "version": 1,
  "rules_version": "demo.1",
  "defaults": { "action": "redact", "censor": "[REDACTED]", "min_score": 0.5 },
  "detectors": [
    {
      "id": "email",
      "description": "标准邮箱地址。误报：noreply@、example.com。",
      "type": "pattern",
      "pattern": "[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}",
      "score": 0.9
    }
  ],
  "operators": [{ "id": "default", "type": "redact" }]
}
```

**顶层字段：**

| 字段 | 说明 |
| --- | --- |
| `version` | 规则格式版本，当前为 `1` |
| `rules_version` | 规则内容版本，写入审计报告，便于溯源 |
| `defaults` | `action` / `censor` / `min_score` 默认值 |
| `detectors` | 检测器数组；**数组顺序参与重叠消解** |
| `operators` | 算子数组，按 `id` 被检测器引用 |
| `policy` | 结构轨白名单：`mode` / `allow_paths` / `ignore_paths` |
| `formats` | 声明适用的输入形态：`json` / `logfmt` / `plain` / `http_headers` |
| `includes` | 规则集组合声明（当前为元数据，加载器不自动合并） |

**检测器类型：**

| `type` | 作用 | 关键字段 |
| --- | --- | --- |
| `pattern` | 正则扫描 | `pattern`、`score`、`validator`、`context` |
| `dictionary` | 词典子串匹配 | `terms`、`case_sensitive` |
| `checksum` | 校验和型候选 | `pattern` + `validator` |
| `composite` | 组合多个检测器 | `detectors`、`targets` |
| `field` | 字段路径（结构轨） | `targets`；v0.1 默认文本轨不消费 |

**算子：**

| `type` | 输出 | 说明 |
| --- | --- | --- |
| `redact` | `[REDACTED]` | 整体替换，默认算子 |
| `replace` | 自定义文本 | `replacement` |
| `mask` | `a***@***` | `keep.prefix` / `keep.suffix` / `fill` |
| `hash` | `h_ab12...` | `algo`：`hmac_sha256`（默认）或 `sha256`；`prefix` / `length` |
| `tokenize` | `h_ab12...` | HMAC(key, `"tok|" + value`)，确定性假名 |
| `encrypt` | `...|rev` | v0.1 占位令牌；AES-GCM 金库在路线图 |
| `keep` | 原值 | 显式放行 |

**校验器：** `luhn`、`cn_id_checksum`、`cn_bank_card_checksum`、`cn_uscc_checksum`、`isbn`、`imei`、`ipv4`、`ipv6`、`base64`、`jwt`。

**上下文打分：** `context.words` 命中加 `boost`，`context.anti_words` 命中减 `penalty`，窗口由 `window`（默认 24 字符）控制；同一命中多个词不叠加，只取一次，保证确定性。

**正则方言（重要）：** 规则正则使用 MoonBit 内置 `lexmatch` 子集。`\d` `\w` `\s` `\b` 不支持，需用 `[[:digit:]]` 等 POSIX 类；字符类内的字面 `-` 写作 `\\-`；不支持 lookahead 与反向引用。`scripts/rules-lint.sh` 会自动检查。

**错误即失败：** 规则加载做 schema + 语义校验（id 重复、引用不存在的 detector / operator、非法正则、缺 `description`……），任一条非法则整个规则集加载失败，不静默跳过。规则语义只依赖数组顺序，不依赖对象键顺序。

## 输出与审计

JS 入口返回单行 JSON：

```json
{"text":"user [REDACTED] login from [REDACTED]","count":2}
```

MoonBit 层拿到的是 `RedactResult`：

| 字段 | 内容 |
| --- | --- |
| `text` | 脱敏后的文本 |
| `report.rules_version` | 规则版本 |
| `report.matched_count` | 命中数 |
| `report.by_entity` | 各实体类型命中数 |
| `report.by_operator` | 各算子命中数 |
| `report.spans` | 每条命中的 `entity` / `start` / `end` / `operator` / `detector` |

审计记录**不含原文**，只含类型、偏移、算子与规则版本。

结构轨另有两个底层 API：`redact_json_policy(text, ruleset)` 做 fail-closed 白名单过滤，`redact_json_fields(text, ruleset, replacements)` 按路径整字段替换。它们不放进默认 `redact` 路径，需要调用方显式选择。

## 架构

```text
输入文本 / JSON / 日志行
└─► load_ruleset      JSON → IR，schema + 语义校验，任一非法整体失败
    └─► detect_all    pattern / dictionary / checksum / composite
        └─► 打分过滤   context boost / penalty · validator
            └─► 重叠消解  score → 声明顺序 → span 长度 → 起点
                └─► 算子   redact / replace / mask / hash / tokenize / encrypt / keep
                    └─► 文本轨区间替换
                        └─► RedactResult { text, report }
```

| 模块 | 职责 |
| --- | --- |
| `core/` | 门面包：只做引擎编排（检测 → 消解 → 算子 → 报告）并 re-export 子包 API |
| `core/json/` | 有序 JSON AST、解析器、序列化、JSON 路径 |
| `core/text/` | `Span` / `Detected` / 确定性重叠消解 |
| `core/rules/` | 规则 IR、JSON → IR 加载与语义校验、上下文窗口配置 |
| `core/detect/` | 四类检测策略（pattern / dictionary / checksum / composite）与上下文打分 |
| `core/ops/` | 七种算子 |
| `core/validate/` | 10 个校验器 |
| `core/structure/` | 格式探测与 JSON 结构轨 |
| `crypto/` | HMAC-SHA256、SHA-256、确定性 token、进程内 Vault |
| `cli/` `js/` `wasm/` | 三个入口包；`cli/app` 承载可测试的 CLI 逻辑，`cli/` 只留 `main` |
| `rules/` | 4 套内置规则：base / cn / secrets / headers |
| `spec/` | 语言无关规范：实体、校验器、算子、JSON Schema、黄金用例与 corpus |
| `scripts/` | 一致性、规则 lint、spec 生成、产物构建、工具链与 MSVC 环境探测 |
| `.github/workflows/` | CI：格式与警告门禁、四端矩阵、跨后端一致性 |

依赖是单向的，没有环：

```text
json / text / validate / ops        （叶子，互不依赖）
        └──► rules ──► detect ──┐
                    structure ──┼──► core（引擎编排 + 门面）
                                ┘
cli / js / wasm 只依赖 core 的门面 API
```

`core/*` 不声明 target，也不依赖平台 API；所有后端差异被限制在入口包。调用方只 import `veil/core` 即可，子包拆分对 API 不可见。

## 一致性保证

「跨后端一致」是约束，不是期望：

- `core/`、`crypto/` 不写 `target` 分支，JS / WASM / WASM-GC / Native 编译同一份源码。
- 检测器按规则数组顺序执行；重叠消解用四级 tie-break（分数 → 声明顺序 → 长度 → 起点），不依赖哈希遍历。
- 文本轨只在原字符串上替换，输出不做二次序列化，天然保序、保空白、保数字原文。
- HMAC 与 token 一律 UTF-8；黄金向量 `HMAC-SHA256("secret-key","hello@example.com") = 928bc0a4...051f6d80`。
- 实测（2026-11-16）：**23 个测试 × wasm / wasm-gc / js / native 全通过**；6 条黄金用例在 JS ESM 产物与 native CLI 上分别逐字节一致。同一口径在 Windows（MSVC）与 GitHub Actions Ubuntu（clang 21）两侧各自复现。

```bash
bash scripts/consistency.sh
```

## 测试与质量

```bash
moon test --target js          # 23 个测试
moon test --target wasm
moon test --target wasm-gc
moon test --target native
bash scripts/rules-lint.sh     # 规则集语法与禁用正则检查
bash scripts/consistency.sh    # 四端 check / test / build + 黄金用例 + HMAC 向量
bash scripts/build.sh          # 构建 JS / WASM / WASM-GC / Native 产物到 dist/
```

| 层 | 内容 |
| --- | --- |
| L1 单元 | 校验器、路径、上下文、算子、JSON 解析 / 序列化、重叠消解 |
| L2 集成 | 规则 JSON → IR → 执行端到端 |
| L3 跨后端 | 同一套用例在 wasm / wasm-gc / js / native 编译并运行 |
| L4 黄金 | `spec/test-cases/cases.json` 逐字节比对（JS ESM + native CLI）+ HMAC 标准向量 |

CI（[`.github/workflows/ci.yml`](./.github/workflows/ci.yml)）把上面这套口径固化成三个 job：

| Job | 覆盖 |
| --- | --- |
| `fmt` | `moon fmt --check`、`moon check --deny-warn`、生成的 `.mbti` 无漂移、规则集 lint、`spec/rules-index.json` 与 `rules/` 同步 |
| `test` | `wasm` / `wasm-gc` / `js` / `native` 四端矩阵：check + test + build |
| `consistency` | `scripts/consistency.sh` 全量一致性、6 条黄金用例、HMAC 向量，并上传 release 产物 |

## API 参考

**MoonBit（`veil/core`）：**

| 函数 | 返回 | 说明 |
| --- | --- | --- |
| `load_ruleset(json)` | `Result[Ruleset, RuleLoadError]` | 严格 JSON → 规则 IR，含语义校验 |
| `redact(text, ruleset, options)` | `RedactResult` | 文本轨脱敏主入口 |
| `redact_json_policy(text, ruleset)` | `Result[String, JsonParseError]` | 结构轨 fail-closed 白名单过滤 |
| `redact_json_fields(text, ruleset, replacements)` | `Result[String, JsonParseError]` | 结构轨按路径整字段替换 |
| `Ruleset::empty()` | `Ruleset` | 空规则集，便于测试 |

**JS ESM：**

| 函数 | 返回 | 说明 |
| --- | --- | --- |
| `version()` | `String` | `0.1.0` |
| `load_ruleset_status(rules)` | `String` | 空串通过；否则返回逐条错误 |
| `redact_text(input, rules, key)` | `String` | `{"text":...,"count":...}`；失败 `count:-1` |
| `tokenize(key, value, prefix, length)` | `String` | 确定性 HMAC 令牌 |
| `hmac_sha256_hex(key, message)` | `String` | UTF-8 HMAC-SHA256 hex |

**WASM / WASM-GC：** `version`、`redact_text`、`tokenize`。

## 目录结构

```text
veil/
├── core/               门面：引擎编排 + 对外 re-export
│   ├── json/           有序 JSON AST / 解析 / 序列化 / 路径
│   ├── text/           Span / Detected / 重叠消解
│   ├── rules/          规则 IR 与加载
│   ├── detect/         检测策略 + 上下文打分
│   ├── ops/            七种算子
│   ├── validate/       10 个校验器
│   └── structure/      格式探测 + JSON 结构轨
├── crypto/             HMAC-SHA256、token、进程内 Vault
├── cli/                CLI 入口（main）
│   └── app/            参数解析 / 文件读写 / 输出格式（含单测）
├── js/ wasm/           两个运行时入口
├── rules/              base / cn / secrets / headers 四套规则
├── spec/               entities / validators / operators / schemas / test-cases
├── scripts/            consistency / rules-lint / gen-spec / build / msvc-env / toolchain-env
├── .github/workflows/  CI：fmt + 四端矩阵 + 一致性
├── moon.mod            模块定义
├── README.md           中文版
├── README.en.md        英文版
├── CHANGELOG.md
└── LICENSE
```

## 已知限制

- **不做 NLP / ML 实体识别。** 自由文本里的人名、地址靠 `dictionary` + 上下文词 + 字段路径补偿，不保证召回。
- **`field` 检测器与结构轨未接入默认路径。** v0.1 的 `redact` 只跑文本轨；字段级处理需显式调用 `redact_json_policy` / `redact_json_fields`，`rules/headers.json` 的字段规则暂不自动生效。
- **`encrypt` 是占位实现。** 返回值是确定性 HMAC 令牌，不是 AES-GCM 密文；`crypto/Vault` 是进程内映射，跨进程不可 restore。
- **`includes` 不自动合并。** 它是声明式元数据；需要按需加载多个规则文件并在调用方合并 detectors。
- **正则是 lexmatch 子集。** 不支持 `\d` `\w` `\s` `\b`、lookahead、反向引用；换规则前先跑 `rules-lint.sh`。
- **WASM 入口的错误处理偏弱。** `redact_text` 在规则加载失败时原样返回输入；生产环境应先在 JS / 构建期验证规则，或改用 MoonBit 层显式处理 `Result`。
- **尚未发布。** mooncakes 与 npm registry 均未发布；包配置与类型声明已就位。
- **Native 构建依赖本机工具链。** Windows 需 MSVC Build Tools（C++ 工作负载 + Windows SDK），Unix 需 clang；仓库不附带预编译二进制。

## 文档与示例

| 文档 | 内容 |
| --- | --- |
| [`README.en.md`](./README.en.md) | English version of this document |
| [`rules/README.md`](./rules/README.md) | 内置规则覆盖范围、误报调整、正则方言 |
| [`spec/schemas/ruleset.schema.json`](./spec/schemas/ruleset.schema.json) | 规则集 JSON Schema |
| [`spec/test-cases/cases.json`](./spec/test-cases/cases.json) | 跨语言黄金用例 |
| [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md) | 实施计划与关键取舍 |
| [`PLAN.md`](./PLAN.md) | 原始计划书 |
| [`CHANGELOG.md`](./CHANGELOG.md) | 版本变更 |

## 贡献

1. 新增 detector / operator / validator 必须同步补 `spec/` 条目、测试用例与 `description`。
2. 规则正则只用 lexmatch 共同子集；`bash scripts/rules-lint.sh` 必须通过。
3. 内置规则不得依赖自定义扩展；改内核后跑 `bash scripts/consistency.sh`。
4. `moon fmt` 格式化；`core/` 不引入平台相关依赖。

## 许可证

Apache-2.0，见 [LICENSE](./LICENSE)。
