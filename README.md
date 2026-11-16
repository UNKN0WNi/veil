# veil

> **跨端 PII 与日志脱敏内核** —— 一份声明式 JSON 规则，四端一致，声明式规则驱动。

[![license](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
[![moonbit](https://img.shields.io/badge/MoonBit-0.1.20261104-orange.svg)](https://www.moonbitlang.com/)
[![backends](https://img.shields.io/badge/backends-wasm%20%7C%20wasm--gc%20%7C%20js%20%7C%20native-green.svg)](#产物矩阵)

给**日志、LLM prompt、HTTP 流量**做 PII / 凭据脱敏：用一份 JSON 规则，编译到 **WebAssembly / WASM-GC / JavaScript / 原生**，各端输出**逐字节一致**。脱敏的一致性是安全属性——客户端说"已脱敏"、服务端却漏脱，是合规事故。veil 用"同一份内核源码 + 语言无关规则"从架构上消除这个缺口。

---

## 目录

- [为什么是 veil](#为什么是-veil)
- [特性](#特性)
- [快速开始](#快速开始)
- [规则格式](#规则格式)
- [四端用法](#四端用法)
- [能力边界（重要）](#能力边界重要)
- [架构](#架构)
- [测试与一致性](#测试与一致性)
- [项目结构](#项目结构)
- [路线图](#路线图)
- [贡献](#贡献)
- [许可证](#许可证)

---

## 为什么是 veil

| 痛点 | veil 的做法 |
|---|---|
| 规则散落在代码里，各端各写一遍 → 漏脱/误伤 | **规则是数据**：全部声明在严格 JSON 里，`spec/` 是语言无关单一事实来源 |
| 同一规则在浏览器/网关/服务端行为不一致 | **四端编译同一份 `core/` 源码**，逐字节一致性测试常驻 CI |
| 大整数 ID（18 位身份证）被 JSON 解析成 Double → 校验和失效 → 漏检 | **文本轨区间替换 + 自建有序 AST**：数字保留原文，键保留顺序 |
| 重复键 `{"email":"real","email":"safe"}` 绕过脱敏 | 解析器**默认拒绝重复键**，报错而非择优 |
| 低熵值（邮箱/手机号）用裸 SHA-256 被彩虹表反查 | 默认 **HMAC-SHA256**，密钥只从环境变量注入 |
| Presidio 依赖 spaCy 模型（数百 MB），边缘/浏览器不可用 | **零外部模型、零网络调用**，wasm 体积目标 ≤ 350 KB |

`spec/` 可被其他语言实现直接消费（类似 [pii-vault](https://github.com/) 的 spec 路线）——MoonBit 是第一个实现，而非唯一实现。

## 特性

- **5 类检测器**：`pattern`（正则）、`dictionary`（词典）、`field`（字段路径）、`composite`（复合）、`checksum`（校验和型）
- **7 类算子**：`redact` / `replace` / `mask` / `hash` / `tokenize` / `encrypt` / `keep`
- **10 个校验器**：Luhn、中国身份证/银行卡/统一社会信用代码、ISBN、IMEI、IPv4、IPv6、JWT、Base64
- **上下文打分**：上下文词 boost / 反上下文词 penalty，命中不叠加（确定性）
- **确定性重叠消解**：分数 → 声明顺序 → 长 span → 起点（四级 tie-break）
- **fail-closed 策略**：`deny_by_default` + 白名单路径，未放行的一律删除
- **审计报告零泄露**：只含实体类型、偏移、算子、规则版本，**绝不含原文**
- **双轨 JSON 处理**：文本轨（默认，保序保精度保空白）+ 有序 AST 结构轨（按需）

## 快速开始

### 环境

需要 MoonBit 工具链（`moon`）。本项目在 `moon 0.1.20261104` 验证。

```bash
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash   # Linux/macOS
# Windows: 见 https://www.moonbitlang.com/download/
moon version
```

### 构建与测试

```bash
moon install                     # 拉取 moonbitlang/x 依赖
moon test --target wasm          # 单元测试（也支持 wasm-gc / js）
bash scripts/rules-lint.sh       # 规则集 lint
bash scripts/consistency.sh      # 跨后端 + 黄金用例一致性验证
bash scripts/build.sh            # 构建四端产物到 dist/
```

### 最小示例

新建规则 `rules/demo.json`：

```json
{
  "version": 1,
  "rules_version": "demo.1",
  "defaults": { "action": "redact", "censor": "[REDACTED]", "min_score": 0.5 },
  "detectors": [
    {
      "id": "email",
      "description": "邮箱",
      "type": "pattern",
      "pattern": "[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}",
      "score": 0.9
    }
  ],
  "operators": [{ "id": "default", "type": "redact" }]
}
```

通过 JS 产物调用（Node，见[四端用法](#四端用法)）：

```js
import { redact_text } from './dist/veil.js';
const rules = JSON.stringify(demoRulesObject);
const out = JSON.parse(redact_text('mail a@b.com now', rules, ''));
// out => { text: 'mail [REDACTED] now', count: 1 }
```

> **注意**：规则正则使用 lexmatch 方言——`\d \w \s \b` 不支持，需用 `[[:digit:]]` 等 POSIX 类；字符类末尾的 `-` 要写 `\\-`。详见 [`rules/README.md`](./rules/README.md)。

## 规则格式

一份规则集是严格 JSON（schema 见 [`spec/schemas/ruleset.schema.json`](./spec/schemas/ruleset.schema.json)）：

```jsonc
{
  "version": 1,
  "rules_version": "2026.11.1",          // 写入审计报告，便于溯源
  "defaults": { "action": "redact", "censor": "[REDACTED]", "min_score": 0.5 },
  "detectors": [
    {
      "id": "cn_phone",                   // snake_case，全局唯一
      "description": "手机号；误报场景：订单号",  // 必填，说明覆盖/误报/调整建议
      "type": "pattern",                  // pattern | dictionary | field | composite | checksum
      "pattern": "1[3-9][0-9]{9}",
      "score": 0.35,                      // 基线分
      "context": {                        // 可选：上下文打分
        "words": ["手机", "电话"], "window": 24, "boost": 0.45, "case_sensitive": false
      },
      "validator": "cn_id_checksum",      // 可选：校验和过滤
      "action": "keep_last4"              // 可选：检测器级算子（覆盖默认）
    }
  ],
  "operators": [
    { "id": "default", "type": "redact" },
    { "id": "keep_last4", "type": "mask", "keep": { "prefix": 0, "suffix": 4 }, "fill": "*" }
  ],
  "policy": { "mode": "deny_by_default", "allow_paths": ["service", "ts", "level"] },
  "formats": ["json", "logfmt", "plain", "http_headers"],
  "includes": ["rules/cn.json"]
}
```

**关键不变量**：规则语义**只依赖 JSON 数组的顺序**（detector 声明顺序用于消解），绝不依赖对象键顺序。JSON 无注释语法，用 `"description"`（必填）与 `"_comment"` 承载说明。

**错误即失败**：规则加载做 schema + 语义校验（id 重复、引用不存在的 detector/operator、非法正则、缺 description……），任一条非法 → 整个规则集加载失败，不静默跳过。理由是"静默漏一条规则"比"直接报错"危险得多。

完整内置规则见 [`rules/`](./rules/README.md)，语言无关实体/算子/校验器定义见 [`spec/`](./spec/)。

## 四端用法

### 产物矩阵

| 产物 | 后端 | 用途 | 构建命令 |
|---|---|---|---|
| `veil.js` / `.d.ts` | js (esm) | npm / Node / 打包器 / 浏览器扩展 | `moon build --target js` |
| `veil.iife.js` | js (iife) | 浏览器 `<script>` / content script | 配置 `link.js.format` |
| `veil.wasm` | wasm (MVP) | 边缘 / 任意 wasm 运行时 | `moon build --target wasm` |
| `veil.wasm` | wasm-gc | 现代浏览器 / 边缘 | `moon build --target wasm-gc` |
| `veil` 二进制 | native | CLI / 服务端 / 管道 | `moon build --target native`（需 MSVC） |

### JavaScript / npm

```bash
moon build --target js
# 产物：_build/js/debug/build/js/js.js（ESM，导出 version / redact_text / tokenize / hmac_sha256_hex）
```

```js
import { redact_text, tokenize, hmac_sha256_hex } from './_build/js/debug/build/js/js.js';

const rules = JSON.stringify({
  version: 1, rules_version: 'demo.1',
  defaults: { action: 'redact', censor: '[REDACTED]', min_score: 0.5 },
  detectors: [{ id: 'email', description: 'email', type: 'pattern',
    pattern: '[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}', score: 0.9 }],
  operators: [{ id: 'default', type: 'redact' }],
});

const { text, count } = JSON.parse(redact_text('a@b.com', rules, ''));
const token = tokenize(process.env.VEIL_KEY || '', 'a@b.com', 'h_', 12);
```

### wasm / wasm-gc（边缘）

`wasm/` 包暴露 `version` / `redact_text` / `tokenize`，编译产物在 `_build/wasm*/debug/build/`。规则作为字符串参数传入，无需文件系统——适合边缘函数与浏览器 Worker。

### CLI（native）

```bash
moon build --target native      # 需 MSVC（Windows）/ clang（ Unix ）
./veil --text "mail a@b.com" --rules rules/base.json --key-env VEIL_KEY --dry-run
```

> 本机验证环境缺少 MSVC `cl.exe`，native 产物由 CI（含 MSVC）按 `scripts/consistency.sh` 验证；wasm/wasm-gc/js 三端本地已全部通过。

### 确定性哈希与密钥

- 哈希/令牌使用 **HMAC-SHA256，UTF-8 编码**（跨语言标准向量：`HMAC-SHA256("secret-key","hello@example.com") = 928bc0a4...051f6d80`）。
- 密钥**只从调用方/环境变量注入**（`--key-env VEIL_KEY`），绝不写入规则文件或日志。
- 低熵值（邮箱、手机号）**必须**用 HMAC；`algo: "sha256"` 仅供高熵值使用。

## 能力边界（重要）

veil 是**确定性强、可移植、边缘可用**的脱敏内核，不是通用 NLP 检测器。明确**不做**：

- ❌ **NLP/ML 实体识别**（自由文本的人名、地址）——无外部模型，靠 `dictionary` + `field` + 上下文词补偿
- ❌ 数据库匿名化 / 测试数据生成
- ❌ 源码静态分析
- ❌ 代理服务 / 网关（只做库 + CLI）
- ❌ 重新序列化整条日志（默认文本轨，**不改写原始格式**）

算子/校验器扩展通过代码注册（自定义实现只在注册它的后端可用）；**内置规则必须 100% 无扩展依赖**，否则破坏四端一致性。这条约束写进 lint。

## 架构

```
输入 (json / logfmt / plain / headers)
  ↓ ① 键级规则先行（field 类型，最快）
  ↓ ② 值级扫描（pattern / dictionary / composite / checksum）
  ↓ ③ 上下文打分（boost / penalty）
  ↓ ④ 校验和过滤（validator）
  ↓ ⑤ 重叠消解（确定性四级 tie-break）
  ↓ ⑥ 执行算子（redact / mask / hash / tokenize / encrypt / keep）
  ↓ ⑦ 文本轨区间替换（保序保精度）或结构轨有序 AST
输出 + 审计报告（不含原文）
```

**JSON 双轨**（§5.3）：`core/json` 用 `Map` 承载对象，键顺序不保证，且大整数转 Double 会丢精度。因此：
- **文本轨**（默认）：只在原始文本上做区间替换，天然保序、保空白、保数字原文、幂等。
- **结构轨**（按需）：自建有序 AST（`Object(Array[(String, JsonValue)])` + `Number(String)`），用于 `field`/`composite` 的整字段替换与 fail-closed 白名单；默认拒重复键。

## 测试与一致性

四层测试（计划书 §7.1）：

| 层 | 内容 |
|---|---|
| L1 单元 | 校验器 / 路径 / 上下文 / 算子 / JSON 解析序列化 / 重叠消解 |
| L2 集成 | 规则 JSON → IR → 执行端到端 |
| L3 跨后端一致性 | `spec/test-cases/cases.json` 在 wasm/wasm-gc/js 逐字节比对 |
| L4 性质 | 幂等性、脱敏文本不含原文子串（黄金用例覆盖） |

```bash
moon test --target wasm && moon test --target wasm-gc && moon test --target js
bash scripts/consistency.sh
```

## 项目结构

```
veil/
├── moon.mod                 # 模块定义（veil 0.1.0）
├── spec/                    # ★ 语言无关规范（单一事实来源，全 JSON）
│   ├── entities.json / validators.json / operators.json
│   ├── schemas/             # ruleset / testcase JSON Schema
│   └── test-cases/          # 跨语言黄金用例 + corpus
├── core/                    # ★ 后端无关内核（span/rule/config/engine/validator/operator/context/path/jsonval/jsonparse/jsonwrite/format）
├── crypto/                  # 确定性令牌 / 可逆金库（x/crypto）
├── cli/ js/ wasm/           # 四端产物入口
├── rules/                   # 内置规则集（base/cn/secrets/headers）
├── scripts/                 # consistency / rules-lint / gen-spec / build
└── testdata/
```

## 路线图

当前版本 **v0.1**（S1–S6 实现 + S7 文档）。详见 [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md) 与原始[计划书](./PLAN.md)。

- [x] 多包工程 + `spec/`（S1）
- [x] 规则系统：5 检测器 + 7 算子 + 10 校验器（S2）
- [x] JSON 双轨内核（S3）
- [x] 三后端一致性框架（S4；native 待 CI）
- [x] 内置规则集（S5）
- [x] CLI + JS/WASM 产物（S6）
- [ ] mooncakes + npm 发布（S7，需账号）
- [ ] WASM 组件 + AES-GCM 金库 + 流式 chunk-invariance（v1）

## 贡献

1. 新增 detector/operator/validator 必须同步补 `spec/` 条目 + 测试用例 + description。
2. 规则正则只用 lexmatch 共同子集；`scripts/rules-lint.sh` 必须通过。
3. 内置规则不得依赖自定义扩展；改内核后跑 `scripts/consistency.sh`。
4. `moon fmt` 格式化；`core/` 不引入平台相关依赖。

## 许可证

Apache-2.0 —— 见 [LICENSE](./LICENSE)。
