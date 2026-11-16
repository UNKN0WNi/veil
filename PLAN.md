# veil 项目计划书

> 跨端 PII 与日志脱敏内核 —— 一份规则（JSON），四端一致，声明式规则驱动

| 项目 | 内容 |
|---|---|
| 项目代号 | **veil**（暂定；备选 `pii-veil` / `scrubber` / `redakt`） |
| 版本 | v0.2（计划书）—— v0.1 基础上落实 D4 决策：**规则格式统一为 JSON** |
| 日期 | 2026-11-16 |
| 状态 | 待评审 |
| 技术栈 | MoonBit（`moon` 工具链） |
| 目标形态 | 可发布的开源库（mooncakes.io + npm）+ 可独立分发的规则规范 `spec/` |

---

## 1. 执行摘要

### 1.1 一句话定位

**给日志、提示词、HTTP 流量做 PII 脱敏：一份声明式 JSON 规则，同时编译到 JS / WASM / WASM-GC / 原生，四端输出逐字节一致。**

### 1.2 三个要点

1. **规则是数据，不是代码。** 全部规则（`spec/` 与 `rules/`）统一使用 **严格 JSON**。检测器（正则 / 校验和 / 上下文 / 词典 / 字段路径 / 复合）、算子（替换 / 遮蔽 / 哈希 / 加密 / 金库）、策略（白名单 fail-closed）全部在 JSON 里声明，无需写代码。
2. **跨端同源。** 客户端本地脱敏、边缘网关脱敏、服务端日志脱敏、CLI 离线脱敏用**同一份规则**，避免"客户端说已脱敏、实际没脱"的安全缺口。
3. **规范先行。** `spec/` 是**语言无关的单一事实来源**，MoonBit 只是第一个实现——这既是护城河，也是社区切入点。

### 1.3 已决策事项（D4 落实）

| 决策 | 结论 | 影响 |
|---|---|---|
| **规则格式统一 JSON**（D4） | ✅ 已定：全部严格 JSON | 消除 YAML 依赖风险（原 R3 关闭）；`moonbitlang/core/json` 为成熟标准库 |
| 规则注释 | JSON 无注释 → 用 `"_comment"` / `"description"` 字段承载 | 可读性有折损，需配套 `rules-lint.sh` 与文档 |
| `spec/` 单独用 JSON | 与 `rules/` 同格式，但**独立目录、独立 schema** | 其他语言实现可零成本消费 |

### 1.4 为什么现在做

- **2026 年的需求爆发**：LLM prompt 脱敏、agent 工具边界（MCP）脱敏、流式场景的边界泄漏、可逆脱敏（mask-and-restore）已成为"上线前提"而非"锦上添花"。
- **生态完全空白**：已扫描 `moonbitlang` + `moonbit-community` 约 315 个仓库 + 6 组关键词交叉检索（pii / redact+mask / censor+scrub / secret+credential / anonymiz / 中文"脱敏"），**零实现**；`pii in:name,description language:moonbit` 总数为 0。
- **底座现成**：`moonbitlang/x/crypto` 已含 HMAC、AES、ChaCha、SM3、SHA-256 —— 确定性假名化、可逆加密、国密合规所需原语**全部到位**。
- **架构已被验证**：`pii-vault`（Rust+TS）用"语言无关 spec + 多语言实现"跑通了这条路；MoonBit 是第一个能同时覆盖 **JS + WASM + 原生** 的实现者。

---

## 2. 跨语言项目调研

> 数据快照：2026-11-16。星数为近似值，随时间变化。

### 2.1 库 / SDK 类（检测 + 脱敏）

| 项目 | 语言 | ★ | 许可证 | 检测方式 | 自定义机制 | 多端 | 对我们的启示 |
|---|---|---|---|---|---|---|---|
| **data-privacy-stack/presidio**（原 Microsoft Presidio） | Python | ~11.5k | MIT | NER(spaCy/Stanza/transformers) + 正则 + 规则 + 校验和 + 上下文词 | **写 Python 代码**定义 recognizer / operator / 语言 | ❌ Python only | 事实标准，API 设计值得抄；**但配置=代码，不可移植**，这正是我们的机会 |
| **pii-vault** | Rust + TS | 新（2026-04） | MIT | 29 个正则识别器，覆盖 17 国 + Luhn + 身份证校验 + 上下文加权 | **JSON spec 文件**（`spec/recognizers/*.json`） | Rust + TS，WASM **planned** | **最重要的标杆**：验证了"spec 目录 = 单一事实来源 + 多语言实现"。其 JSON 化路线与我们一致 |
| **awslabs/ferret-scan** | Go | ~100 | Apache-2.0 | 正则 + 上下文置信度，格式保留脱敏 | 正则规则 | CLI + Go 库 | "格式保留"（format-preserving）是高价值特性，纳入 v1.1 |
| **censgate/redact** | Rust | ~22 | Apache-2.0 | PII + secrets | 自定义规则 | CLI / 网关 / Postgres 扫描器 / **WASM** | 声称 32× Presidio；**已有 WASM 目标**，是 wasm 侧的直接竞争者 |
| **DataFog/datafog-python** | Python | ~80 | MIT | 正则为主 + 可选 spaCy/GLiNER | 规则文件 | 离线防火墙 / Claude Code hook / LiteLLM guardrail | "离线 + 零网络调用"是明确卖点 |
| **hoophq/alcatraz** | Go | ~39 | MIT | PII 检测 + 掩码 | **自定义规则** | Go | 小而专的引擎形态，API 极简设计可参考 |
| **krypsis-io/wick** | Go | ~125 | Apache-2.0 | 日志与命令输出中的 secrets + PII | — | CLI + Go | 定位清晰：**日志与命令输出**场景 |
| **crp4222/PrivAiTe** | Python | ~38 | BSD-3 | PII + secrets | 自定义 | **可逆代理**（脱敏后复原） | 可逆（mask-and-restore）是刚需场景，做进内核 |
| **flare-collection/flare-redact** | TS | ~48 | MIT | secrets + PII | — | SDK / 日志 / HTTP / LLM prompt / **MCP 边界** | 覆盖面清单可直接抄成我们的场景矩阵 |
| **raphz/datamask** | Java | ~12 | Apache-2.0 | **注解驱动** | 注解 | Jackson / Logback / OTel / Kafka / JDBC / Spring Boot | 注解驱动 = 编译期检查，但**注解不可跨语言**；JSON 配置更通用 |
| **sformisano/redactable** | Rust | ~7 | MIT | 库 | — | Rust | 库形态 |
| **stella/anonymize** | Rust + TS | ~8 | Apache-2.0 | 确定性、local-first | — | Rust + TS | "确定性 + local-first"定位与我们一致 |
| **jqueguiner/presidio-rs** | Rust | ~3 | MIT | Presidio 移植 | — | Rust + Python binding | 移植路线可行但价值有限 |
| **scrubadub** | Python | — | Apache-2.0 | 正则 + 姓名词典 | 有限 | Python | 2023 年后停更，**已被 Presidio 取代** |
| **Marker-Inc-Korea/ko-pii** | Python | ~101 | MIT | 韩语 PII | — | Python | **语言包化**方向正确：实体定义应可独立分发 |
| **intenthq/anon** | Go | ~35 | MIT | 规则 | — | UNIX CLI | 极简 CLI 形态参考 |
| **CGI-FR/PIMO** | Go | ~43 | GPL-3.0 | 数据掩码 | — | Go | GPL —— 我们要用 Apache/MIT |
| **HodeTech/Leakwatch** | Go | ~414 | MIT | **secrets 扫描**（非 PII） | — | Go / 容器 / Git 历史 | 高性能 secret 扫描参考；注意 secret ≠ PII，是两个品类 |
| **GreenmaskIO/greenmask** | Go | ~1.75k | Apache-2.0 | 数据库匿名化 / 测试数据 | 策略 | Postgres / MySQL | 数据库侧是另一个大品类（暂不进入 v1） |
| **httptape/httptape** | Go | ~219 | Apache-2.0 | HTTP 流量录制 + 脱敏回放 | — | Go | HTTP 录制场景作为 v2 场景 |
| **arcjet/arcjet-js** | TS | ~682 | Apache-2.0 | PII + 运行时安全 | — | JS | 商业化形态参考 |

### 2.2 日志 / 可观测性侧（脱敏作为管道能力）

| 项目 | 机制 | 配置形态 | 关键设计 |
|---|---|---|---|
| **OpenTelemetry Collector `redaction` processor** | `allowed_keys` / `allow_all_keys` / `ignored_keys` / `blocked_key_patterns` / `blocked_values`(regex) / `summary` | YAML | **fail-closed**：allowed_keys 为空 → 全删。审计属性 `redaction.masked.count` |
| **OTel `attributes` processor** | `action: hash / delete / insert` | YAML | 按 key 处理（不跑正则，最快） |
| **OTel `transform` processor + OTTL** | `replace_pattern(log.body, ...)` | OTTL | 处理日志正文（redaction processor 只管属性） |
| **pino**（Node） | `redact: { paths: [...], censor: "[REDACTED]" }` | 代码 | 路径式配置，支持通配 |
| **logback `MaskingConverter`** / **log4j2 `MaskingPatternLayout`** | 正则整体替换 | XML 配置 | 日志框架内建脱敏 |
| **Symfony PHP `#[SensitiveParameter]`** | 注解，调用栈自动遮蔽 | 注解 | **框架级内建**——最好的脱敏发生在"源头"，而非事后扫描 |
| **Arakiss/vestig** | 结构化日志库内置 PII 清洗 | 库 | 脱敏与日志格式一体化 |

### 2.3 行业共识（必须遵守的 8 条）

1. **检测与脱敏分离**（Presidio Analyzer / Anonymizer）——两个独立阶段，可单独使用。
2. **检测手段是混合的**：正则 + 校验和 + 上下文词 + 词典 + 结构化字段。**单一正则不够**，必须可组合。
3. **校验和降误报**：Luhn（信用卡）、中国身份证校验位、ISBN —— 被反复验证的高性价比手段。
4. **多种运算符**：replace / redact / mask / hash / encrypt / vault(可逆) / keep。
5. **fail-closed 默认**：白名单模式比黑名单更安全（OTel redaction processor 的明确设计）。
6. **可逆脱敏有真实需求**：LLM 场景需要"模型看到假名、用户看到真名"。
7. **上下文词提升置信度**：同一个 `13800138000` 出现在"手机:"旁边才是手机号。
8. **本地优先 / 数据不出网**：DataFog、PrivAiTe、prompt-scrubber 都把"零网络调用"当卖点。

### 2.4 行业空白（我们的机会）

| # | 空白 | 证据 |
|---|---|---|
| **G1** | **没有"一份规则、多语言实现"的成熟范式被广泛采纳** | `pii-vault` 是唯一做到的（Rust+TS，2026-04 才起步，体量小） |
| **G2** | **配置=代码 vs 配置=声明式的断层** | Presidio（写 Python）、datamask（写注解）、alcatraz（写 Go）都是代码配置；只有 OTel 是声明式，但能力仅限 key+regex 两类 |
| **G3** | **没有跨端一致性保证** | 每个实现各自为政；"同一规则在客户端和服务端行为一致"无人保证，而这恰恰是安全属性 |
| **G4** | **WASM/边缘侧成熟实现少** | `censgate/redact` 有 WASM 但体量小；Presidio 依赖 spaCy 模型（数百 MB），边缘不可用 |
| **G5** | **中文/亚洲实体覆盖不足** | Presidio 偏欧美；ko-pii 只做韩语；**中国身份证/手机/银行卡/统一社会信用代码几乎无人系统做**（pii-vault 有身份证 checksum，是少数） |
| **G6** | **流式场景的边界泄漏无人处理** | 跨 chunk 边界被切断的 PII 几乎必然漏检 |
| **G7** | **JSON 键顺序与重复键问题在脱敏场景被忽视** | 见 §5.3，这是脱敏工具特有的安全与一致性陷阱，多数项目未处理 |

### 2.5 我们与最接近标杆的差异

| 维度 | Presidio | pii-vault | **veil（我们）** |
|---|---|---|---|
| 检测手段 | NER + 正则 + 校验和 + 上下文 | 正则 + 校验和 + 上下文 | 正则 + 校验和 + 上下文 + 词典 + 字段路径 + 复合（**无 NLP**，见 §6.1） |
| 规则形态 | Python 代码 | JSON 文件 | **JSON + schema 校验 + 规则集组合与版本化** |
| 目标平台 | Python | Rust + TS | **JS + WASM + WASM-GC + 原生（同时）** |
| 可逆脱敏 | 需自建 | Vault（内置） | **内置（HMAC 假名化 + AES-GCM 金库）** |
| 跨端一致性 | 不适用 | 未提供保证 | **核心卖点：逐字节一致性测试套件** |
| 中文实体 | 弱 | 中（身份证） | **中（身份证/手机/银行卡/USCC/护照）** |
| JSON 键顺序 / 重复键 | 未特殊处理 | 未特殊处理 | **显式处理（§5.3）** |
| 流式安全 | 无 | 无 | **chunk-invariance 保障（v1.1）** |

---

## 3. 空白定位与项目定义

### 3.1 为什么"多后端"在这里是真需求（而非炫技）

脱敏的一致性是**安全属性**，不是体验优化：

```
客户端本地脱敏（用户输入框 / 扩展 / 浏览器）
        ↓ 客户端说"已脱敏，可以信任"
边缘网关脱敏（API 网关 / LLM 代理 / 反向代理）
        ↓
服务端日志脱敏（落库前的最后一道）
```

规则不一致会导致两类严重后果：
- **漏脱**：客户端窄规则、网关宽规则 → 用户以为已脱敏的数据落库了（合规事故）
- **误伤**：客户端宽规则改写了不该改的字段 → 与服务端/下游对不上（功能事故）

**结论**：脱敏规则必须**同源**。这使"一份源码 → 四端产物"成为刚需。

### 3.2 三个黄金用例

**U1 — 日志管道脱敏**
```
输入：{"user":{"email":"a@b.com","phone":"13800138000"},"msg":"..."}
输出：{"user":{"email":"h_3f2a...","phone":"138****8000"},"msg":"..."}
```
同一份规则，在服务端（native CLI）与边缘（wasm）产出**逐字节相同**。

**U2 — LLM prompt 本地脱敏（可逆）**
```
输入：prompt 含真实姓名与邮箱
输出：[PERSON_a3f2] / [EMAIL_9c1d] 送往模型
响应回来后本地复原 → 用户看到真实内容
```
浏览器端（js）本地完成，数据不出网；密钥由用户自持。

**U3 — HTTP 头与查询串脱敏**
```
Authorization: Bearer xxx  →  Authorization: [REDACTED]
?email=a@b.com&token=xyz   →  ?email=h_...&token=[REDACTED]
```

### 3.3 明确的非目标

- ❌ **不做 NLP/ML 实体识别**（人名、地址这类自由文本 PII）——MoonBit 生态无 NLP 依赖，引入会破坏"零依赖、小体积、边缘可用"。取舍论证见 §6.1。
- ❌ 不做数据库匿名化 / 测试数据生成（Greenmask 的地盘）
- ❌ 不做源码静态分析（Bearer / Privado 的地盘）
- ❌ 不做代理服务 / 网关（只做库 + CLI）
- ❌ **不改写原始日志格式**（不重新序列化整条日志）——见 §5.3 文本轨设计

### 3.4 与 content-kit 的关系

两个项目**共享同一套工程基建**（多包工程骨架、四后端构建脚本、跨后端一致性测试框架、CI 矩阵）。`content-kit` 先落地基建，`veil` 复用之。若只做一个，先做 veil（规则系统更独立、更快出成品）。

---

## 4. 核心：规则配置模型（统一 JSON）

### 4.1 设计原则

| 原则 | 落地 |
|---|---|
| **声明式** | 纯 JSON，零代码扩展 |
| **可校验** | 规则集加载前做 schema 校验；错误规则**不静默跳过**，直接报错 |
| **可组合** | 规则集可 `include` 多个文件；检测器可组合成复合规则 |
| **可版本化** | `version` 字段 + 语义化版本；规则变更记录在 `rules_version` 审计字段 |
| **fail-closed** | 默认 `deny_by_default`（结构化场景只放行白名单键） |
| **确定性** | 相同输入 + 相同规则 + 相同密钥 → 相同输出（四后端一致） |
| **格式中立** | 规则不依赖输入格式；同一份规则适用于 JSON / logfmt / plain / headers |

### 4.2 配置文件全貌（`rules/base.json`）

> JSON 无注释语法，用 `"_comment"` 承载说明；每条规则必须有 `"description"`。

```json
{
  "version": 1,
  "rules_version": "2026.11.1",

  "defaults": {
    "action": "redact",
    "censor": "[REDACTED]",
    "min_score": 0.5
  },

  "detectors": [
    {
      "id": "email",
      "description": "标准邮箱地址。正则取自 RFC 5322 实用子集。误报场景：邮件列表里的 noreply@ 会被一起脱敏。",
      "type": "pattern",
      "pattern": "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b",
      "score": 0.9
    },

    {
      "id": "credit_card",
      "description": "银行卡号。必须过 Luhn 校验，否则 16 位订单号会造成大量误报。",
      "type": "pattern",
      "pattern": "\\b(?:\\d[ -]*?){13,19}\\b",
      "validator": "luhn",
      "score": 0.95
    },

    {
      "id": "cn_id_card",
      "description": "中国大陆居民身份证号。含 GB 11643 加权校验位，误报率极低。",
      "type": "pattern",
      "pattern": "\\b[1-9]\\d{5}(?:19|20)\\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\\d|3[01])\\d{3}[\\dXx]\\b",
      "validator": "cn_id_checksum",
      "score": 0.95
    },

    {
      "id": "cn_bank_card",
      "description": "中国大陆银行卡号（16-19 位），ISO/IEC 7812 校验。",
      "type": "pattern",
      "pattern": "\\b\\d{16,19}\\b",
      "validator": "cn_bank_card_checksum",
      "score": 0.9
    },

    {
      "id": "cn_phone",
      "description": "中国大陆手机号。裸数字歧义大（可能是订单号），故基线分低，靠上下文词提分。",
      "type": "pattern",
      "pattern": "\\b1[3-9]\\d{9}\\b",
      "score": 0.35,
      "context": {
        "words": ["手机", "电话", "联系方式", "联系电话", "phone", "tel", "mobile"],
        "window": 24,
        "boost": 0.45,
        "case_sensitive": false
      }
    },

    {
      "id": "internal_codename",
      "description": "内部项目代号词典。需按公司维护，建议放在公司私有规则集而非内置规则。",
      "type": "dictionary",
      "terms": ["Project Falcon", "代号 猎鹰", "Northwind"],
      "case_sensitive": false,
      "score": 0.95,
      "action": "replace",
      "replacement": "[PROJECT]"
    },

    {
      "id": "sensitive_headers",
      "description": "HTTP 敏感请求头。按字段路径定位，不跑正则，最快。",
      "type": "field",
      "targets": [
        "http.request.header.authorization",
        "http.request.header.cookie",
        "http.request.header.set-cookie",
        "http.request.header.x-api-key"
      ],
      "action": "redact"
    },

    {
      "id": "secret_fields",
      "description": "常见密钥字段名。命中字段路径后整值脱敏，不做值级扫描。",
      "type": "field",
      "targets": ["*.password", "*.passwd", "*.secret", "*.token", "*.api_key", "*.access_key"],
      "action": "redact"
    },

    {
      "id": "email_in_profile",
      "description": "复合规则：先定位 user.email 字段，再对其值跑 email 检测器，最后做 HMAC 假名化。",
      "type": "composite",
      "targets": ["user.email", "user.contact"],
      "detectors": ["email"],
      "action": "hash"
    }
  ],

  "operators": [
    { "id": "default", "type": "redact" },
    {
      "id": "keep_last4",
      "type": "mask",
      "keep": { "prefix": 0, "suffix": 4 },
      "fill": "*"
    },
    {
      "id": "stable_hash",
      "type": "hash",
      "algo": "hmac_sha256",
      "key_env": "VEIL_KEY",
      "length": 12,
      "prefix": "h_"
    },
    {
      "id": "vault",
      "type": "encrypt",
      "algo": "aes_gcm",
      "key_env": "VEIL_VAULT_KEY",
      "reversible": true
    }
  ],

  "policy": {
    "mode": "deny_by_default",
    "allow_paths": ["service", "ts", "level", "trace_id", "duration_ms"],
    "ignore_paths": ["request_id", "trace_id"]
  },

  "formats": ["json", "logfmt", "plain", "http_headers"],

  "includes": ["rules/cn.json", "rules/secrets.json", "rules/headers.json"]
}
```

### 4.3 检测器类型全表

| type | 说明 | 关键字段 |
|---|---|---|
| `pattern` | 正则匹配 | `pattern`, `flags`, `score` |
| `dictionary` | 词典 / gazetteer | `terms`, `case_sensitive`, `score` |
| `field` | 按结构化字段路径定位 | `targets`（支持 `*` 通配） |
| `composite` | 字段定位 + 值检测 | `targets`, `detectors[]` |
| `checksum` | 纯校验和型（候选提取 + 校验） | `extract`, `validator` |

### 4.4 校验器（validators）

| 名称 | 覆盖 | 说明 |
|---|---|---|
| `luhn` | 信用卡 | 行业标准，误报率降低一个数量级 |
| `cn_id_checksum` | 中国大陆居民身份证 | GB 11643 加权校验 |
| `cn_bank_card_checksum` | 中国大陆银行卡 | Luhn 变体（ISO/IEC 7812） |
| `cn_uscc_checksum` | 统一社会信用代码 | GB 32100 字符加权 |
| `isbn` | ISBN-10/13 | 图书/标准号 |
| `imei` | IMEI | 设备标识 |
| `ipv4` / `ipv6` | IP 地址 | 含私有地址段判定 |
| `base64` | 疑似 base64 凭据 | 熵检查 |
| `jwt` | JWT | 结构校验 |
| `custom` | 用户自定义 | 通过 MoonBit 插件接口注册（§4.9） |

### 4.5 运算符（operators）

| type | 效果 | 可逆 | 确定性 | 典型用途 |
|---|---|---|---|---|
| `redact` | 整体删除 | — | — | 最安全默认 |
| `replace` | 替换为固定字符串 | — | ✅ | 分类占位，如 `[EMAIL]` |
| `mask` | 保留前后若干字符 | ❌ | ✅ | 保留末 4 位便于排障 |
| `hash` | SHA-256 / HMAC-SHA256 摘要 | ❌ | ✅ | 跨日志关联同一用户 |
| `encrypt` | AES-GCM / ChaCha20-Poly1305 | ✅ | ✅ | 金库式可逆脱敏 |
| `tokenize` | 确定性令牌 + 可选金库 | 可选 | ✅ | 同一实体全局同一 token |
| `keep` | 不处理（白名单豁免） | — | — | 显式放行 |
| `custom` | 用户自定义变换 | 取决于实现 | 取决于实现 | 特殊业务格式 |

### 4.6 上下文打分（context）

```
final_score = base_score
            + (命中上下文词 ? boost : 0)
            - (命中反上下文词 ? penalty : 0)
```
- `words`：上下文词表（可含正则）；`window`：距离（字符数）；`boost` / `penalty`：增量；`case_sensitive`：默认 false
- 同一命中多个上下文词**不叠加**（取最高 boost），保证确定性

### 4.7 重叠与冲突消解（必须确定性）

1. **分数高者优先**；同分 → **检测器声明顺序在前者优先**
2. 完全包含时，**长 span 优先**（更具体）
3. 部分重叠时，取分数较高者的 span，另一方被裁剪
4. 同一 span 命中多个检测器时，取**声明顺序最靠前**的，但记录 `matched_by[]` 全部命中

> 消解逻辑写在 `core/` 的纯函数中，四后端共享同一份实现 → 一致性由架构保证。

### 4.8 结构化路径与 fail-closed

路径语法（借鉴 pino 的 path 风格并扩展）：

```
user.email                  精确
user.*.phone                单层通配
*.token                     前缀通配
http.request.header.authorization
```

- `deny_by_default`：**只保留白名单键**，其余键按规则处理或整体删除
- `allow_by_default`：全部键通过检测器扫描
- `ignore_paths`：豁免键（连白名单都不需要）

### 4.9 自定义扩展点（代码逃生舱）

```moonbit
///|
pub trait CustomValidator {
  name : String
  validate : (String) -> Bool
}

///|
pub trait CustomOperator {
  name : String
  apply : (String, Detected) -> String
}
```

在 MoonBit 中实现后注册进引擎；JSON 侧用 `"validator": "my_checker"` / `"action": "my_op"` 引用。

> **重要约束**：自定义扩展只在注册它的后端可用 → **内置规则必须 100% 无扩展依赖**，否则四端一致性会被破坏。这条约束写进文档与 lint 规则。

### 4.10 规则集加载与校验流程

```
读文件 → JSON 解析 → schema 校验 → 语义校验 → 编译为 IR → 执行
         │            │            │           │
         │            │            │           └─ 规则编译一次，多次复用
         │            │            └─ 检查：id 重复、引用不存在的 detector/operator、
         │            │               路径语法非法、include 循环依赖、字段类型错误
         │            └─ schema：必填项、枚举值合法性、正则可编译
         └─ 语法错误
```
**错误即失败**：任一条规则非法 → 整个规则集加载失败（不静默跳过）。理由：脱敏系统"静默漏一条规则"比"直接报错"危险得多。

---

## 5. 技术架构

### 5.1 包结构

```
veil/
├── moon.mod                      # name = "veil"
├── spec/                         # ★ 语言无关规范（单一事实来源，全部 JSON）
│   ├── entities.json             # 实体类型定义（名称/描述/默认算子/默认分值）
│   ├── validators.json           # 校验器行为定义
│   ├── operators.json            # 算子定义
│   ├── schemas/
│   │   ├── ruleset.schema.json   # 规则集 JSON Schema（用 JSON Schema 描述 JSON）
│   │   └── testcase.schema.json
│   └── test-cases/
│       ├── cases.json            # 输入 + 期望输出 + 期望命中（跨语言可比）
│       └── corpus/               # 真实日志/提示词样本
├── core/                         # ★ 后端无关：引擎内核
│   ├── moon.pkg
│   ├── span.mbt                  # Detected / Span / Overlap
│   ├── rule.mbt                  # 规则 IR 与加载后模型
│   ├── config.mbt                # JSON → IR 的解析与校验
│   ├── engine.mbt                # 扫描 + 消解 + 执行（纯函数）
│   ├── validator.mbt             # 内置校验器实现
│   ├── operator.mbt              # 内置算子实现
│   ├── context.mbt               # 上下文打分
│   ├── path.mbt                  # 结构化路径匹配
│   ├── jsonval.mbt               # ★ 有序 JSON 值类型（自建，见 §5.3）
│   ├── jsonparse.mbt             # ★ JSON 解析器（保序 + 拒重复键 + 保数字原文）
│   ├── jsonwrite.mbt             # ★ JSON 序列化（确定性）
│   ├── format.mbt                # json / logfmt / plain / http_headers 适配
│   └── *_test.mbt
├── crypto/                       # 确定性令牌 / 可逆金库
│   ├── moon.pkg
│   ├── token.mbt                 # HMAC-SHA256 令牌
│   ├── vault.mbt                 # AES-GCM 金库（带碰撞处理）
│   └── *_test.mbt
├── cli/                          # 原生产物：veil 命令
│   ├── moon.pkg                  # pkgtype(kind: "executable")
│   ├── main.mbt
│   └── *_test.mbt
├── js/                           # js 产物：npm 包
│   ├── moon.pkg                  # link.js.format = "esm"
│   ├── main.mbt
│   └── *_test.mbt
├── wasm/                         # wasm / wasm-gc 产物
│   ├── moon.pkg
│   ├── main.mbt
│   └── *_test.mbt
├── rules/                        # 内置规则集（全部 JSON）
│   ├── base.json                 # 通用：email / url / ip / jwt / key 等
│   ├── cn.json                   # 中国：身份证 / 手机 / 银行卡 / USCC
│   ├── secrets.json              # AWS AKIA / GitHub token / 私钥
│   └── headers.json              # HTTP 头
├── scripts/
│   ├── consistency.sh            # 四后端逐字节比对
│   ├── rules-lint.sh             # 规则集 lint
│   └── gen-spec.sh               # 从 rules/ 生成 spec/ 索引
├── testdata/
├── README.md
├── CHANGELOG.md
└── LICENSE                       # Apache-2.0
```

### 5.2 产物矩阵

| 产物 | 后端 | 用途 | 体积目标 |
|---|---|---|---|
| `veil.js` + `.d.ts` | js (esm) | npm / Node / 打包器 / 浏览器扩展 | ≤ 300 KB |
| `veil.iife.js` | js (iife) | 浏览器 `<script>` / 扩展 content script | ≤ 300 KB |
| `veil.wasm` | wasm (MVP) | 边缘 / 任意 wasm 运行时 | ≤ 350 KB |
| `veil.wasm` | wasm-gc | 现代浏览器 / 边缘 | ≤ 350 KB |
| `veil` 二进制 | native | CLI / 服务端 / 管道 | ≤ 4 MB |
| `veil.component.wasm` | wasm + WIT | WASM 组件生态（v1.0） | ≤ 350 KB |

### 5.3 ★ JSON 处理架构：文本轨为主，结构轨为辅

这是本项目最关键的技术决策，直接由源码调研得出。

#### 5.3.1 问题：MoonBit 的 `core/json` 不适合做"保序输出"

已从 `moonbitlang/core` 源码确认：

```moonbit
// core/json/parse.mbt
fn ParseContext::parse_object(...) -> Json {
  let map = Map([])
  ...
  map[name] = ctx.parse_value(...)
  break Json::object(map)     // ← 对象由 Map 承载
}
```

```moonbit
// core/json/json.mbt
pub fn Json::as_object(self : Json) -> Map[String, Json]?   // ← 转成 Map，顺序丢失
Object(Iter[(String, Json)], mut first~ : Bool)              // ← 内部是迭代器
```

**结论**：`core/json` 解析出的对象，键顺序是 **Map 的迭代顺序**，**不是源文件的插入顺序**。由此产生三个具体问题：

| # | 问题 | 后果 |
|---|---|---|
| **P1** | 输出 JSON 的键顺序不确定 | 若 Map 哈希顺序跨后端或跨运行不一致 → **逐字节一致性彻底失败**，日志 diff / 审计比对 / golden test 全部失效 |
| **P2** | 大整数精度丢失 | 18 位身份证若以 JSON number 出现，会被转成 Double → **末位错误 → 校验和失效 → 漏检**（`preserve_number_repr` 选项存在，正是为此） |
| **P3** | 重复键（key smuggling） | `{"email":"a@b.com","email":"safe@x.com"}` —— 不同解析器可能取第一个或最后一个，**绕过脱敏**（`reject_duplicate_keys` 选项存在，正是为此） |

`core/json` 已提供 `reject_duplicate_keys` 与 `preserve_number_repr` 两个公开选项（`@json.parse(input, reject_duplicate_keys=true)`），**必须开启**。但**键顺序问题它解决不了**。

#### 5.3.2 解法：双轨设计

```
┌─ 文本轨（primary）─────────────────────────────────────┐
│ 原始文本 → 定位 span → 按 span 做区间替换 → 拼回原文      │
│  ✓ 保序（不改原结构）  ✓ 保精度  ✓ 保原格式与空白        │
│  ✓ 不需要重建 JSON                                      │
└─────────────────────────────────────────────────────────┘
┌─ 结构轨（optional）─────────────────────────────────────┐
│ 需要按路径操作时才解析成有序 AST                        │
│  ✓ 支持 user.email 这类路径规则                          │
│  ✓ 支持字段级重写（hash 整字段 / 删字段）                │
└─────────────────────────────────────────────────────────┘
```

**文本轨（默认路径）**：
1. 用 `core/json` 的 tokenizer 思路做**只读扫描**，得到"字符串值区间"与"键区间"的列表（不构造对象）
2. 对字符串值跑检测器；对非字符串值（如大整数）用原始文本跑检测器（保住精度）
3. 收集所有命中 span，按起点排序、裁剪重叠
4. **在原始文本上做区间替换** → 输出天然保持原键序、原空白、原格式

**结构轨（按需）**：
- 仅当规则含 `field` / `composite` 类型时启用
- 使用**自建有序 JSON AST**（`core/jsonval.mbt`）：
  ```moonbit
  ///|
  pub(all) enum JsonValue {
    Null
    Bool(Bool)
    Number(String)                          // 保留原始文本，不转 Double
    Str(String)
    Array(Array[JsonValue])
    Object(Array[(String, JsonValue)])      // ★ 有序：插入顺序即输出顺序
  }
  ```
- 自建解析器（约 400–600 行）实现：保序、拒重复键、保数字原文
- **输出路径**：结构轨只在"必须改结构"时启用（删字段/整字段替换）；默认仍是文本轨回写

> **决策**：v1 同时实现文本轨 + 一个**最小有序 AST**（仅支持路径定位与整字段替换，不支持任意结构重建）。这让 v1 就能覆盖 95% 场景，且避免"重建 JSON"带来的顺序/精度/重复键三重风险。完整 AST 与结构重建放 v1.1。

#### 5.3.3 幂等性保证

文本轨天然幂等：`redact(redact(x)) == redact(x)`（因为已脱敏片段不再匹配检测器，或匹配到但被算子替换成同一结果）。这一点在性质测试中验证（§7.1 L4）。

### 5.4 执行流水线

```
输入 (text / json / logfmt / headers)
  ↓  ① 解析为结构化上下文（格式适配器，文本轨优先）
  ↓  ② 键级规则先行（field 类型，最快，不跑正则）
  ↓  ③ 值级扫描（pattern / dictionary / composite）
  ↓  ④ 上下文打分（context boost / penalty）
  ↓  ⑤ 校验和过滤（validator）
  ↓  ⑥ 重叠消解（确定性规则）
  ↓  ⑦ 执行算子（redact / mask / hash / encrypt ...）
  ↓  ⑧ 回写（文本轨：区间替换；结构轨：有序 AST 序列化）
输出 + 审计报告（命中类型/数量/规则版本，不含原文）
```

**性能关键**：② 键级规则先跑，避免对每个字段值都做全量正则扫描（借鉴 OTel 管道中 "attributes processor 先于 redaction processor" 的顺序设计）。

### 5.5 审计报告

```moonbit
///|
pub(all) struct RedactionReport {
  rules_version : String
  matched_count : Int
  by_entity : Map[String, Int]
  by_operator : Map[String, Int]
  spans : Array[MatchRecord]   // 类型 + 偏移 + 算子，不含原值
}
```
`spans` 里**绝不含原文**，只含类型与位置 —— 审计报告本身不能成为新的泄露源。

### 5.6 一致性保证（核心壁垒）

| 层级 | 手段 |
|---|---|
| 架构 | 四后端编译**同一份 `core/` 源码**；`spec/` 与 `rules/` 是数据不是代码 |
| 数据 | `spec/test-cases/cases.json` 是**跨语言**期望输出，任何实现（含非 MoonBit）都可跑 |
| 自动化 | `scripts/consistency.sh` 四后端逐字节比对，CI 必跑 |
| 规则 | 规则集用 JSON + `rules_version` 标注，输出携带版本号 |
| 确定性 | 哈希用 HMAC-SHA256（`x/crypto/hmac`），**不依赖平台的 `hash` 随机化**（⚠️ R2） |
| 顺序 | 文本轨不改原结构；结构轨用自建有序 AST（⚠️ R2' 已解决） |

> **强主张**：`veil` 的 `spec/` 可被其他语言实现消费（就像 `pii-vault` 那样），MoonBit 是第一个实现而非唯一实现。这把生态风险转成生态机会。

---

## 6. 关键设计取舍

### 6.1 为什么不做 NLP（人名/地址识别）

| 反对 | 回应 |
|---|---|
| Presidio 的 NER 很强大 | 但依赖 spaCy/transformers 模型（数百 MB），**边缘与浏览器不可用**；而 veil 的核心场景（浏览器本地、边缘网关、嵌入式）恰恰要求小体积 |
| 不做 NER 会漏人名 | 确实会。**这是明确取舍**，v1 靠上下文词 + 词典 + 字段路径覆盖大部分实际场景；README 与文档必须明确写出能力边界 |
| 竞争者会做 | `pii-vault` 同样只做正则 + 校验和 + 上下文，**市场已验证该取舍可行** |

**补偿**：`dictionary` 检测器 + `field` 路径规则 + 上下文词，让用户用自己的词典/字段清单补齐。

### 6.2 为什么规则统一用 JSON（而不是 YAML / TOML）

| 格式 | 判断 |
|---|---|
| YAML | 表达力好但**无 JSON Schema 生态**、依赖 `moonbit-community/yaml`（仅 1★，成熟度待验证）→ 放弃 |
| TOML | 表达力弱，深层嵌套可读性差；`toml-parser` 仅 3★ → 放弃 |
| **JSON** | ✅ **采用**：① `moonbitlang/core/json` 是成熟标准库（Apache-2.0，持续维护）② 可用 **JSON Schema** 描述与校验（`spec/schemas/*.schema.json`）③ **零解析歧义**，任何语言实现可零成本消费 `spec/` ④ 与 `pii-vault` 的 spec 路线一致，便于互操作 |

**代价与补偿**：

| 代价 | 补偿方案 |
|---|---|
| JSON 无注释语法 | ① 每条规则强制 `"description"` 字段（schema 校验必填）② 用 `"_comment"` 承载额外说明 ③ 配套 `rules-lint.sh` 检查 description 缺失 ④ 提供 `rules/README.md` 说明每条规则的误报场景 |
| 无尾随逗号容忍 | schema 校验报错并给出行列位置（自建解析器可精确定位） |
| 键顺序在规则文件中无意义 | 规则语义**不依赖键顺序**；检测器的"声明顺序"以 **`detectors` 数组下标**为准（数组保序，天然稳定） |

> **重要设计约束（写入 ADR）**：**规则的语义只能依赖 JSON 数组的顺序，绝不能依赖对象的键顺序。** 这条约束让规则在任意 JSON 实现下行为一致。

### 6.3 为什么用 HMAC 而不是裸 SHA-256 做哈希

- 裸 SHA-256(邮箱) 可被**彩虹表**直接反查（邮箱、手机号这类低熵值尤其致命）
- HMAC-SHA256 带密钥 → 无法离线反查
- **但**：HMAC 必须保证四后端**字节级一致**（R2）
- 提供 `"algo": "sha256"` 选项，但文档明确标注"仅用于高熵值，低熵值请用 HMAC"

### 6.4 为什么不做代理/网关

Grepture / PrivAiTe 证明"代理层"是有效商业形态，但代理需要长期运维（证书、升级、可用性）→ 不适合 OSS 库定位；库可以被放进任何代理里 → 保持"库 + CLI"形态，覆盖面更广。

**v2 可选**：基于 `moonbitlang/async` 的极简反向代理示例（演示用，非产品）。

---

## 7. 工程与质量

### 7.1 测试策略（四层）

| 层 | 内容 | 目标 |
|---|---|---|
| L1 单元 | `core/` 纯函数（路径匹配、上下文打分、消解、算子、校验器、JSON 解析/序列化） | 覆盖率 ≥ 85% |
| L2 集成 | JSON → IR → 执行端到端；规则集 schema 校验 | 每个内置规则集有正/负用例 |
| L3 **跨后端一致性** | `spec/test-cases` 在四后端跑，输出逐字节比对 | **零差异** |
| L4 性质测试 | quickcheck 生成随机文本/结构，验证不变量 | 不崩溃；`redacted_text` 不含原文子串；**幂等性** `redact(redact(x)) == redact(x)` |

**L4 的幂等性测试很关键**：脱敏函数必须幂等，否则重试/多管道会破坏数据。

### 7.2 CI 矩阵

```
moon fmt --check
moon check --target native|js|wasm|wasm-gc
moon test  --target native|js|wasm|wasm-gc
scripts/rules-lint.sh         # 内置规则集 lint（schema + 语义 + description 必填）
scripts/consistency.sh        # 四后端逐字节比对（PR 必跑）
```

### 7.3 性能预算（release）

| 指标 | native | js | wasm |
|---|---|---|---|
| 脱敏 1 MB 日志文本（10 条规则） | ≤ 60 ms | ≤ 200 ms | ≤ 120 ms |
| 单行 1 KB JSON 日志脱敏 | ≤ 30 µs | ≤ 100 µs | ≤ 60 µs |
| 规则集加载（100 条规则） | ≤ 20 ms | ≤ 50 ms | ≤ 40 ms |
| 产物体积 | ≤ 4 MB | ≤ 300 KB | ≤ 350 KB |

### 7.4 代码规范

- `moon fmt` 强制；不依赖隐式 `impl` 方法提升（用显式 `extend`）
- `core/` 内禁止任何后端相关 import
- 每条内置规则必须有 `"description"`，说明**覆盖什么、典型误报场景、调整建议**
- 规则 id 用 snake_case，全局唯一
- 任何算子/校验器新增必须同步补 `spec/` 条目与测试用例
- **规则的语义不得依赖 JSON 对象键顺序**（§6.2）

---

## 8. 里程碑

> 以 2026-11-23 为 S0 起点。

| 阶段 | 时间 | 交付物 | 验收标准（可执行验证） |
|---|---|---|---|
| **S0 预研** | 11/23 – 11/29 | Spike 报告 | ① 工具链安装跑通；② **HMAC-SHA256 四后端字节一致**；③ **正则引擎四后端行为一致**（含中文、Unicode、大小写、lookahead 支持情况）；④ **Map 迭代顺序在四后端是否一致**（是否随运行变化）；⑤ `core/json` 的 `reject_duplicate_keys` / `preserve_number_repr` 实际行为；⑥ `x/crypto` API 确认 |
| **S1 骨架 + spec** | 11/30 – 12/06 | 多包工程 + `spec/` 初版 | `spec/entities.json` 45 个实体 + `schemas/*.schema.json`；`moon check` 四后端全绿 |
| **S2 规则系统** | 12/07 – 12/21 | JSON → IR → 引擎 | 5 类检测器 + 8 类算子 + 10 个校验器可用；规则集加载校验生效 |
| **S3 JSON 内核** | 12/15 – 12/24 | 自建有序 JSON 解析/序列化 + 文本轨 | 保序、保数字原文、拒重复键；文本轨区间替换可用 |
| **S4 一致性框架** | 12/22 – 01/03 | `spec/test-cases` + `consistency.sh` | 四后端逐字节零差异 |
| **S5 内置规则集** | 01/04 – 01/17 | `rules/*.json` | base 25 条 / cn 15 条 / secrets 20 条 / headers 10 条；每条含 description |
| **S6 CLI + npm** | 01/18 – 01/31 | `veil` CLI + npm 包 | CLI 支持 `--rules --format --output --dry-run`；npm 可安装可用 |
| **S7 v0.1 发布** | 02/01 – 02/07 | 发布 + 文档 | mooncakes + npm 双发布；README/文档/示例齐全 |
| **S8 v1.0** | 02/08 – 03/07 | WASM 组件 + 可逆金库 + 流式保障 | 组件可被 wit-bindgen 消费；chunk-invariance 测试通过 |

**关键路径**：S0 → S1 → S2 → S3 → S4。S5 与 S6 可并行。

---

## 9. 风险登记册

| ID | 风险 | 概率 | 影响 | 缓解 | 触发信号 |
|---|---|---|---|---|---|
| **R1** | **正则引擎四后端行为不一致**（lookahead/backref/Unicode 大小写/中文） | **高** | **高**（破坏一致性） | S0 第 3 天验证；规则集只用四后端共同支持的语法子集；`rules-lint.sh` 检查禁用语法 | S0 发现差异 |
| **R2** | **HMAC/AES 四后端字节不一致** | 中 | **高** | S0 第 2 天验证；必要时自实现 HMAC（仅依赖 SHA-256 原语）；`spec/test-cases` 内置固定密钥向量 | S0 发现差异 |
| **R2'** | **Map 迭代顺序跨后端/跨运行不一致** → JSON 输出键顺序漂移 | 中 | **高** | **已由 §5.3 架构化解**：文本轨不改原结构；结构轨用自建有序 AST；S0 第 4 项实测 Map 行为作为佐证 | S0 实测发现顺序随机 |
| **R2''** | **大整数精度丢失**导致身份证等校验和失效 | **高**（若用 core/json 默认行为） | **高** | 文本轨对非字符串值用原始文本匹配；结构轨 `Number(String)` 保留原文；开启 `preserve_number_repr` | 集成测试出现漏检 |
| **R2'''** | **重复键 key smuggling** 绕过脱敏 | 中 | **高**（安全） | 自建解析器默认拒重复键；`core/json` 路径开启 `reject_duplicate_keys=true`；重复键出现即报错而非择优 | 安全测试用例 |
| **R3** | ~~YAML 解析能力不足~~ | — | — | ✅ **已关闭**：统一 JSON，`moonbitlang/core/json` 为成熟标准库 |
| **R4** | 内置规则误报率高（手机号、身份证正则易误判） | 高 | 中 | 校验和兜底 + 上下文词 + 分值阈值；每条规则带"典型误报"说明；真实语料回归 | S5 实测误报 > 5% |
| **R5** | 中文实体覆盖不足，用户仍需自己写 | 高 | 中 | 明确写入能力边界；提供 `dictionary` + `field` 让用户自助；提供 `rules/cn.json` 模板 | 用户反馈 |
| **R6** | 不做 NLP 导致"看起来不如 Presidio" | 中 | 中 | 文档用"边缘可用 / 小体积 / 零依赖 / 四端一致"对比，而非准确率对比；定位互补而非替代 | 社区反馈 |
| **R7** | MoonBit 工具链不稳定（官方自述不适用于生产环境） | 中 | 中 | 锁定工具链版本；`core/` 只依赖 `moonbitlang/core`；HMAC/AES 隔离在 `crypto/` 包 | 上游 breaking change |
| **R8** | 生态冷启动，无人使用 | 中 | 高 | ① `spec/` 作为跨语言资产吸引他语言实现；② 与 `pii-vault` 社区建立互操作（互补而非竞争）；③ 提 PR 到 OTel / pino 生态做参考实现 | S7 后 4 周下载 < 50 |
| **R9** | 密钥管理做错导致安全反噬 | 低 | **高** | 密钥只从环境变量读，绝不入配置与日志；文档强调 HMAC 优于裸哈希；vault 密钥与数据分离 | 代码评审 |
| **R10** | 范围蔓延到做代理/网关/数据库/NLP | 中 | 中 | §3.3 非目标写入 README；新需求先进 issue | PR 偏离 |
| **R11** | JSON 规则文件缺注释导致可维护性下降 | 中 | 低 | `"description"` 必填 + lint 强制；`rules/README.md` 说明每条规则误报场景 | 贡献者反馈 |

---

## 10. 社区与增长

| 阶段 | 动作 | 目标 |
|---|---|---|
| S1–S3 | 发布 `spec/` 草案并征求意见；联系 `pii-vault` 作者探讨互操作 | 2 份外部反馈 |
| S4 | 把 `spec/test-cases` 做成**跨语言可跑的一致性套件**，邀请其他语言实现接入 | 1 个外部实现 |
| S7 | 技术文章《为什么脱敏规则应该是数据而不是代码》；对比 Presidio / pii-vault / OTel | 100★ |
| S8 | 提交 OTel Collector 的 MoonBit processor 提案；与 `pino`/OTel 社区互推 | 300★ |

**差异化传播点**：不是"又一个 PII 检测库"，而是"**把脱敏规则变成可移植的数据资产，并保证四端行为一致**"。

---

## 11. 成功指标

| 类别 | 指标 | v0.1 | v1.0 | 6 个月 |
|---|---|---|---|---|
| 一致性 | 四后端逐字节一致率 | 100% | 100% | 100% |
| 一致性 | `spec/test-cases` 外部实现接入数 | 0 | 0 | ≥ 1 |
| 检测 | 内置实体类型数 | 45 | 55 | 70 |
| 检测 | 内置校验器数 | 10 | 12 | 15 |
| 检测 | 内置规则条目数 | 70 | 100 | 150 |
| 检测 | 真实语料误报率 | ≤ 8% | ≤ 5% | ≤ 3% |
| 安全 | 重复键绕过用例全部被拒 | ✅ | ✅ | ✅ |
| 安全 | 大整数 ID 校验和正确率 | 100% | 100% | 100% |
| 配置 | 规则集 lint / JSON Schema 校验 | ✅ | ✅ | ✅ |
| 性能 | native 脱敏 1 MB 文本 | ≤ 80 ms | ≤ 60 ms | ≤ 50 ms |
| 体积 | wasm 产物体积 | ≤ 400 KB | ≤ 350 KB | ≤ 300 KB |
| 生态 | GitHub stars | 50 | 200 | 600 |
| 生态 | mooncakes 周下载 | — | 100 | 500 |
| 生态 | npm 周下载 | — | 80 | 300 |
| 生态 | 外部贡献者 | 0 | 1 | 3 |

---

## 12. 决策记录

### 12.1 已决策

| ID | 决策 | 结论 | 日期 |
|---|---|---|---|
| **D4** | 规则格式 | ✅ **统一 JSON**（严格 JSON；`spec/` 与 `rules/` 同格式不同 schema；注释用 `description` / `_comment`） | 2026-11-16 |
| **D7** | JSON 处理架构 | ✅ **文本轨为主 + 自建有序 AST 为辅**（§5.3） | 2026-11-16 |

### 12.2 待决策

| 决策点 | 时间 | 选项 A | 选项 B | 判定依据 |
|---|---|---|---|---|
| D1 正则能力 | S0 末 | 用内置 `regexp.mbt` | 自实现受限正则子集 | 四后端行为一致性；R1 结论 |
| D2 JSON 实现 | S2 | 基于 `core/json` 扩展 | 完全自建 | `core/json` 的 lexer 是否可复用（目前 lexer 为私有）；保序需求（R2'） |
| D3 哈希实现 | S0 末 | `x/crypto/hmac` | 自实现 HMAC（基于 SHA-256 原语） | 四后端字节一致性；R2 结论 |
| D5 首发范围 | S7 | 仅 base 规则集 | base + cn + secrets + headers | 国内用户占比决定 |
| D6 是否做 NLP | 长期 | 坚持不做 | 接入轻量 NER（需外部服务） | 边缘可用性优先；v1 不做 |
| D8 结构轨深度 | S3 | 最小 AST（路径定位 + 整字段替换） | 完整 AST（任意结构重建） | v1.1 范围与工作量 |

**总体 Plan B**：若 MoonBit 工具链或生态动荡，`spec/` + `rules/` + `test-cases` 是**纯 JSON 数据资产**，任何语言都能实现并通过一致性测试 —— 项目不会归零，反而有机会成为跨语言事实标准。

---

## 附录 A：调研证据索引

| 结论 | 来源 |
|---|---|
| Presidio 为事实标准，~11.5k★，MIT，已转社区治理（data-privacy-stack） | data-privacy-stack/presidio README / FAQ |
| Presidio 检测 = NER + 正则 + 规则 + checksum + 上下文；算子 = remove/replace/hash/encrypt/mask | Presidio FAQ「What are the main building blocks」 |
| Presidio 自定义靠**写代码**（recognizer / operator / language） | Presidio FAQ「How can Presidio be customized」 |
| Presidio 官方声明"不保证找到全部敏感信息" | Presidio README warning |
| Presidio **Python only**，非 Python 栈需起 HTTP 服务 | Grepture 对比页 |
| pii-vault 用 `spec/`（entities.json + recognizers/*.json + test-cases/）做语言无关单一事实来源 | lib.rs/crates/pii-vault 文档 |
| pii-vault 29 个识别器覆盖 17 国，含 Luhn 与**中国身份证校验** | 同上 |
| pii-vault 算子含 **Vault（确定性可逆）**；WASM 仍为 planned | 同上 |
| OTel redaction processor **fail-closed**，支持 blocked_key_patterns / blocked_values / summary 审计 | opentelemetry-collector-contrib redactionprocessor 文档 |
| OTel 管道顺序建议：先 key 级 attributes，再值级 redaction，再 transform/OTTL | safeguard.sh / OneUptime 博客 |
| pino `redact.paths` + `censor` 路径式配置 | pino 文档 |
| Symfony PHP `#[SensitiveParameter]` 属性 | Symfony 文档 |
| ferret-scan 支持**格式保留**脱敏与上下文置信度 | awslabs/ferret-scan README |
| DataFog / PrivAiTe / prompt-scrubber 均主打**本地优先、零网络调用** | 各项目 README |
| **`core/json` 解析对象用 `Map` 累加 → 键顺序 = Map 迭代顺序，非插入顺序** | `moonbitlang/core` 源码 `json/parse.mbt` `ParseContext::parse_object` |
| **`Json::as_object()` 返回 `Map[String, Json]`**；`Json::Object` 内部为 `Iter[(String, Json)]` | `moonbitlang/core` 源码 `json/json.mbt` |
| **`@json.parse` 提供 `reject_duplicate_keys` 与 `preserve_number_repr` 两个公开选项** | `moonbitlang/core` 源码 `json/parse.mbt` 公开签名与文档注释 |
| `moonbit-community/yaml` 仅 1★、`toml-parser` 仅 3★ → 不作为规则格式依赖 | 生态仓库扫描（2026-11-16） |
| `moonbitlang/x/crypto` 含 hmac / aes / chacha / sha256 / sm3 / md5 / bcrypt / jwt / uuid | x 仓库目录结构 |
| MoonBit 生态 PII/脱敏方向**零实现** | `moonbitlang` + `moonbit-community` 全量扫描 + 6 组关键词检索（2026-11-16）；`pii in:name,description language:moonbit` 总数 0 |

---

## 附录 B：S0 预研任务清单

| # | 任务 | 验证方式 | 通过标准 |
|---|---|---|---|
| B0 | 安装工具链 | `curl -fsSL https://cli.moonbitlang.com/install/unix.sh \| bash`（**必须 bash**，脚本含 `[[` 与函数语法） | `moon version` 有输出 |
| B1 | 四后端冒烟构建 | `moon new spike` 后 `moon build --target native\|js\|wasm\|wasm-gc` | 四个目标全部成功，记录体积 |
| B2 | **HMAC 一致性** | 同一密钥 + 同一消息，四后端算 HMAC-SHA256 | 四份 hex **完全相同** |
| B3 | **正则一致性** | 含 lookahead / backref / 中文 / 大小写 / `\w` 边界的用例集 | 记录四后端差异表；得出"可用语法子集"清单 |
| B4 | **Map 迭代顺序** | 同一段含 10 个键的 JSON，四后端各解析并 stringify 20 次 | 记录：是否保序？是否跨运行稳定？跨后端是否一致？ |
| B5 | **JSON 数值与重复键** | 用 `@json.parse(x, reject_duplicate_keys=true, preserve_number_repr=true)` 解析 18 位整数与重复键样本 | 确认数字原文保留；重复键被拒 |
| B6 | `x/crypto` API 确认 | 查 hmac / aes / sha256 的实际 API 签名 | 明确调用方式 |
| B7 | 空白复核 | 复查 6 组关键词 + `mooncakes.io` 包搜索 | 确认无同名/同类包 |
| B8 | 规则格式 D2 决策 | 评估 `core/json` lexer 能否复用；对比自建成本 | 形成 ADR |
| B9 | 语料种子 | 收集 20 条真实脱敏日志样本（已脱敏） | 落盘 `testdata/` |

---

## 附录 C：术语表

| 术语 | 含义 |
|---|---|
| **Detector** | 检测器：从文本中定位 PII 候选片段的规则 |
| **Operator** | 算子：对命中片段执行的变换动作 |
| **Validator** | 校验器：对候选片段做算法级校验以降误报 |
| **Span** | 命中片段（起止偏移 + 类型 + 分数） |
| **IR** | 中间表示：规则集加载后的编译产物 |
| **fail-closed** | 默认拒绝：未明确放行的字段一律不通过 |
| **确定性假名化** | keyed hash：同一密钥下同一值恒定映射到同一 token |
| **金库（vault）** | 存储 token↔原值映射的可逆机制 |
| **chunk-invariance** | 流式场景下跨 chunk 边界的 PII 不被切断漏检 |
| **spec/** | 语言无关规范目录（全部 JSON）：实体、算子、校验器定义与跨语言测试用例 |
| **文本轨** | 在原始文本上做区间替换，不重建结构（默认路径） |
| **结构轨** | 解析为有序 AST 后按路径操作（按需启用） |
| **key smuggling** | 用 JSON 重复键让不同解析器取到不同值的绕过手法 |
