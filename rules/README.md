# 规则自定义指南

这里的 `.json` 就是 veil 的全部"策略"。**改行为不用碰代码，只改这些文件**：加一条自己的正则、把邮箱改成打码、压掉某类误报，都在规则里完成。

规则是严格 JSON（不允许 `//` 注释），所以说明写在三个约定字段里，加载器一律忽略：

| 约定 | 写在哪儿 | 作用 |
| --- | --- | --- |
| `$schema` | 各文件第一行 | 指向 `../spec/schemas/ruleset.schema.json`。用 VS Code / JetBrains 打开时，字段名有补全、每个字段有中文说明 |
| `_comment` | 顶层、`defaults`、`operators[]`、`policy` | 一句话说明这段配置在干什么 |
| `_how_to_customize` | 顶层，字符串数组 | 「想改什么、改哪个字段」的速记，留给下一个维护者 |

改完记得验证：`bash scripts/rules-lint.sh`（语法与禁用正则）→ 用 CLI 跑一条真实样本看效果。

## 30 秒上手：最小可跑规则集

把下面内容存成 `my-rules.json`，就是一个能用的规则集：

```json
{
  "$schema": "../spec/schemas/ruleset.schema.json",
  "version": 1,
  "rules_version": "my.1",
  "_comment": "只脱敏公司工号（EMP-12345）和邮箱。",
  "defaults": { "action": "redact", "censor": "[REDACTED]", "min_score": 0.5 },
  "detectors": [
    {
      "id": "employee_id",
      "description": "公司工号 EMP- 加 5 位数字。误报：文档里的示例号。",
      "type": "pattern",
      "pattern": "EMP-[[:digit:]]{5}",
      "score": 0.9
    },
    {
      "id": "email",
      "description": "标准邮箱地址。",
      "type": "pattern",
      "pattern": "[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}",
      "score": 0.9
    }
  ],
  "operators": [{ "id": "default", "type": "redact" }]
}
```

跑一下：

```bash
# native CLI（--rules 是必填项，没有默认值）
veil --text "张三 EMP-12345 邮箱 zhang@corp.com" --rules my-rules.json --json

# 或者 JS
node --input-type=module -e '
import * as veil from "./_build/js/debug/build/js/js.js";
import fs from "node:fs";
const rules = fs.readFileSync("my-rules.json", "utf8");
console.log(veil.load_ruleset_status(rules));            // 空串 = 规则合法
console.log(veil.redact_text("mail zhang@corp.com", rules, ""));
'
```

输出里 `count` 是命中条数，`text` 是替换后的字符串。`--dry-run` 只看命中区间不输出结果，调试正则时很好用。

## 字段速查

### 顶层

| 字段 | 必填 | 说明 | 什么时候动它 |
| --- | --- | --- | --- |
| `version` | 是 | 规则格式版本，固定 `1` | 不要动 |
| `rules_version` | 是 | 规则内容版本，写进审计报告 | 每次改规则升一位（`2026.11.1` → `2026.11.2`） |
| `defaults` | 否 | `action` / `censor` / `min_score` 的默认值 | 想全局换占位符或调松紧 |
| `detectors` | 是 | 检测器数组 | 加/改实体都在这里 |
| `operators` | 否 | 自定义算子表，按 `id` 被引用 | 想给不同实体不同输出形态 |
| `policy` | 否 | 结构轨白名单：`mode` / `allow_paths` / `ignore_paths` | 处理 JSON 字段时 |
| `formats` | 否 | 声明适用形态：`json` / `logfmt` / `plain` / `http_headers` | 纯文档元数据 |
| `includes` | 否 | 想一起用的其他规则文件路径 | 仅声明，**加载器不自动合并** |

`defaults` 三项：`action` 默认算子、`censor` redact 的替换文本（默认 `[REDACTED]`）、`min_score` 命中阈值（默认 `0.5`，越大越保守）。

### 检测器（`detectors[]`）

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `id` | 是 | 小写 snake_case，全局唯一，会出现在统计里 |
| `description` | 是 | 写清「管什么 + 典型误报 + 怎么调」，lint 要求非空 |
| `type` | 是 | `pattern` / `checksum` / `dictionary` / `field` / `composite` |
| `pattern` | 条件 | `pattern` / `checksum` 用；**只能写 lexmatch 方言**（见下） |
| `validator` | 否 | 命中后再算一次校验位，不通过就丢弃；可选值与 `spec/validators.json` 一致：`luhn`、`cn_id_checksum`、`cn_bank_card_checksum`、`cn_uscc_checksum`、`isbn`、`imei`、`ipv4`、`ipv6`、`base64`、`jwt` |
| `score` | 否 | 基础分 0–1，默认 `0.5`；与上下文加减分相加后和 `min_score` 比 |
| `action` | 否 | 这条用哪个算子：写类型（`mask`）或 `operators` 里的 id（`mask_email`） |
| `terms` | 条件 | `dictionary` 用，词表子串匹配 |
| `targets` | 条件 | `field` 用，字段路径（`*.password`、`http.request.header.cookie`） |
| `detectors` | 条件 | `composite` 用，引用其他检测器 id |
| `case_sensitive` | 否 | `dictionary` 是否区分大小写，默认 `false` |
| `context` | 否 | 上下文打分，见下 |

`context` 子字段：`words`（加分词）、`anti_words`（减分词）、`window`（窗口字符数，默认 24）、`boost`（加分，如 `0.45`）、`penalty`（减分）、`case_sensitive`。

### 算子（`operators[]` 或直接写在 `action` 里）

| `type` | 效果 | 关键字段 |
| --- | --- | --- |
| `redact` | 整段替换成 `censor` | — |
| `replace` | 替换成自定义文本 | `replacement` |
| `mask` | 保留首尾、中间打码 | `keep.prefix` / `keep.suffix` / `fill` |
| `hash` | 哈希摘要 | `algo`（`hmac_sha256` / `sha256`）、`prefix`、`length` |
| `tokenize` | HMAC 确定性假名，可跨日志关联 | `prefix`、`length` |
| `encrypt` | 可逆占位（当前为占位实现） | — |
| `keep` | 显式放行，不改 | — |

低熵值（邮箱、手机号）**别用裸 `sha256`**：同一输入永远同一摘要，彩虹表能反查。用 `hmac_sha256`，密钥从调用方或环境变量注入，不进规则文件。

## 四类检测器怎么选

| 想要 | 用 | 说明 |
| --- | --- | --- |
| 按形状匹配（邮箱、工号、token） | `pattern` | 最常用 |
| 形状像 + 校验位能算（身份证、银行卡） | `checksum`（或 `pattern` + `validator`） | 误报率最低 |
| 固定词表里出现的词（内部项目名） | `dictionary` | 不用写正则 |
| JSON 字段整体脱敏（`*.password`） | `field` | 不跑正则，最快 |
| 几个检测器结果合并 | `composite` | `detectors` 列出子 id |

## 常见调整配方

### 1. 误报太多

按代价从小到大依次试：

1. 加 `validator`：能算校验位的类型直接丢弃伪命中。
2. 加 `context.anti_words` + `penalty`：例如手机号规则里加 `"订单号"`，命中就扣分。
3. 提高该条 `score`，或提高 `defaults.min_score`（后者影响全局，谨慎）。
4. 收紧正则（加边界、限定位数）。

### 2. 漏报

1. 降 `score` 或降 `min_score`。
2. 加 `context.words` + `boost`，让"附近有相关词就升级为命中"。
3. 放宽正则位数范围。

### 3. 只在特定上下文才脱敏

裸 11 位数字可能是手机号也可能是订单号。让上下文决定：

```json
{
  "id": "cn_phone",
  "description": "大陆手机号：裸数字歧义大，靠上下文词提分。",
  "type": "pattern",
  "pattern": "1[3-9][0-9]{9}",
  "score": 0.35,
  "context": {
    "words": ["手机", "电话", "联系方式", "phone", "tel", "mobile"],
    "anti_words": ["订单号", "order_id"],
    "window": 24,
    "boost": 0.45,
    "penalty": 0.3,
    "case_sensitive": false
  }
}
```

算法：`0.35 + 0.45 = 0.80 ≥ 0.5` → 上下文有「手机」才脱敏；没有上下文词 `0.35 < 0.5` → 不动。同一个命中命中多个词也只加一次分，保证结果确定。

### 4. 换输出形态：同一条规则三种效果

```json
{ "id": "email", "action": "mask_email" }   // z*************：只留首字符
{ "id": "email", "action": "stable_hash" }  // h_8cb9cf2b1b94：稳定假名
{ "id": "email", "action": "keep" }         // 显式放行，便于临时排查
```

`action` 写 id 时，`operators` 里必须有同 id 的定义（`base.json` 里已给出 `mask_email` / `stable_hash` 两个例子）。

### 5. 加一个自己的实体

1. 在 `detectors` 数组里追加一条，`id` 唯一、`description` 别偷懒（lint 会检查，也是给同事看的）。
2. 先在文本上手工验证正则，再写进文件——lexmatch 方言不支持 `\d`，用 `[[:digit:]]`。
3. 跑 `bash scripts/rules-lint.sh`。
4. 用 `veil --text "<样本>" --rules 你的文件 --json` 确认 `count` 与替换结果符合预期。

顺序有讲究：新检测器放在数组靠前，与已有实体重叠时会优先占位。

### 6. 白名单 / 跳过字段（处理 JSON 时）

```json
"policy": {
  "_comment": "只处理命中检测器的字段；追踪 id 直接跳过。",
  "mode": "allow_by_default",
  "allow_paths": ["request_id"],
  "ignore_paths": ["request_id", "trace_id"]
}
```

`mode` 改成 `deny_by_default` 会更安全（默认遮蔽，只放行 `allow_paths`），但正常字段也容易被误伤，适合高敏场景。

### 7. 临时停用某条规则

直接把那条 detector 从数组里删掉——比把 `score` 设 0 干净，也不会因为残留规则影响重叠消解的先后顺序。

## 正则方言（最容易踩的坑）

veil 用 MoonBit 内置 `lexmatch` 正则子集，四后端行为一致。规则正则**只能**用共同支持的语法：

- ✅ POSIX 字符类 `[[:digit:]]` `[[:alpha:]]` `[[:alnum:]]` `[[:space:]]`
- ✅ 分组 `( )` `(?: )`、或 `|`、量词 `{n,m}`、锚点 `^ $`、`.` 
- ✅ 字符类里的字面 `-` 写成 `\\-`（JSON 字符串里是两个反斜杠）
- ❌ 禁用 `\\d` `\\w` `\\s` `\\b` —— 换成 POSIX 类
- ❌ 禁用 lookahead / 反向引用 —— 四后端行为不一致

`scripts/rules-lint.sh` 会检查以上禁用语法。

## 内置四套规则集

| 文件 | 覆盖 | 条数 |
| --- | --- | --- |
| `base.json` | email / URL 凭据 / IPv4 / IPv6 / JWT | 5 |
| `cn.json` | 身份证 / 手机号 / 银行卡 / 统一社会信用代码 | 4 |
| `secrets.json` | AWS / GitHub / 私钥 / Slack / 通用 api_key | 5 |
| `headers.json` | HTTP 敏感头 / 密钥字段路径（`field` 类型） | 2 |

`base.json` 的 `includes` 列出了其余三份；需要合并使用时，由调用方分别加载后拼接 `detectors`（顺序即优先级）。

## 语义约定

- 规则语义**只依赖数组顺序**，不依赖 JSON 对象键顺序。
- 重叠消解四级 tie-break：分数 → 声明顺序 → 长度 → 起点，结果确定。
- 任何一条规则非法（id 重复、引用不存在的 validator / operator、正则非法、缺 `description`）都会让**整份规则集加载失败**，不会静默跳过——宁可报错，不要悄悄少脱敏。
- `rules_version` 会写进审计报告，便于回溯某次输出用的是哪版规则。

## Field reference (English)

The guide above is in Chinese; field names are stable and the schema carries per-field descriptions. Condensed reference:

| Field | Where | Meaning |
| --- | --- | --- |
| `version` | top level | Rule format version, always `1` |
| `rules_version` | top level | Content version, copied into the audit report |
| `defaults.action` / `censor` / `min_score` | top level | Fallback operator, redaction text, hit threshold (default `0.5`) |
| `id` / `description` / `type` | detector | snake_case unique id, required prose, detector kind |
| `pattern` | detector | lexmatch regex; `\d \w \s \b` are unsupported, use `[[:digit:]]` |
| `validator` | detector | Post-check that drops false positives: `luhn`, `cn_id_checksum`, `ipv4`, `jwt`, … |
| `score` | detector | Base score 0–1; combined with context boosts, compared against `min_score` |
| `action` | detector | Operator type or operator `id` from `operators[]` |
| `context.words` / `anti_words` / `window` / `boost` / `penalty` | detector | Contextual scoring around a match (window defaults to 24 chars) |
| `terms` / `targets` / `detectors` | detector | For `dictionary` / `field` / `composite` types |
| `operators[]` | top level | `redact` / `replace` / `mask` / `hash` / `tokenize` / `encrypt` / `keep` |
| `policy` | top level | Structural-track whitelist: `mode`, `allow_paths`, `ignore_paths` |
| `_comment`, `_how_to_customize`, `$schema` | anywhere | Documentation only; ignored by the loader |
