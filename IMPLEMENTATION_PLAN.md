# veil 实施计划书（S0 预研后修订版）

> 依据 `PLAN.md`（v0.2 计划书），结合本机 MoonBit 工具链实测结果制定的可执行实施计划。
> 本文件是"先写计划书，再完成"中第一步的产物；第二步按此计划落地代码。

| 项目 | 内容 |
|---|---|
| 源计划书 | `C:/Users/Administrator/Downloads/PLAN.md` |
| 工具链 | `moon 0.1.20261104`（本机实测，位于 `.../2026-11-14-23-34-36/.tools/moonbit/bin`） |
| 日期 | 2026-11-16 |
| 状态 | S1–S6 完成；native 已补齐并验证 |

> 2026-11-16 更新：已安装 MSVC Build Tools 2022 + Windows SDK 10.0.26100，`native` 构建、20 个单测与 native CLI 黄金用例全部通过。下文 S0 中"native 目标不可用"是初次预研时的环境结论，保留作历史记录；native 环境由 `scripts/msvc-env.sh` 自动导入。

---

## 0. S0 预研实测结论（决定架构的关键事实）

在 `_spike/` 中用真实工具链验证了计划书的 B0–B6 项，结论如下：

| 编号 | 验证项 | 实测结论 | 对计划的影响 |
|---|---|---|---|
| B0/B1 | 工具链与多后端 | `moon check/test` 在 **wasm / wasm-gc / js** 三后端可用；初次预研时 **native 目标不可用**（缺 MSVC `cl.exe`，VS2022 目录为空）；2026-11-16 已安装 MSVC 并补齐 native | 一致性框架覆盖四后端；native CLI 已构建并验证 |
| B2 | HMAC-SHA256 一致性 | `@crypto.hmac(@crypto.SHA256::new(), k, m)` + `@crypto.bytes_to_hex_string`，三后端输出**逐字节一致**（`928bc0a4...051f6d80`） | **D3 决策：采用 `x/crypto` 内置 HMAC**，不自实现 |
| B3 | 正则一致性 | `@string.Regex("...")` 三后端行为一致；但语法是 **lexmatch 子集**：`\d \w \s \b` **不支持**，须用 `[[:digit:]]` 等 POSIX 类；字符类末尾的 `-` 非法须写 `\-` | **D1 决策：用内置 regexp**；所有规则正则改写为 lexmatch 方言，lint 检查禁用语法 |
| B4 | Map 顺序 | `core/json` 对象底层是 `Map`，顺序不保证；`@json.parse` 保留输入文本顺序仅因 stringify 走原始 token | 证实 **D7**：文本轨 + 自建有序 AST 是必需的，不能依赖 Map |
| B5 | 数值/重复键 | `@json.parse(..., preserve_number_repr=true)` 保留 `123456789012345678` 原文；`reject_duplicate_keys=true` 生效 | 规则加载与结构轨解析均开启这两个选项 |
| B6 | x/crypto API | 含 `sha256/hmac`（可用）；AES 仅 `ecb/cbc`，**无 GCM** | 可逆金库 v0.1 用 **HMAC 令牌 + 映射表**实现 tokenize/vault，AES-GCM 留 v1 |

**风险状态更新**：R1（正则不一致）→ 已通过"只用 lexmatch 共同子集 + lint"缓解；R2（HMAC 不一致）→ 已关闭；R2'（Map 顺序）→ 已由架构化解。

---

## 1. 关键决策记录（ADR 摘要）

| ID | 决策 | 结论 |
|---|---|---|
| D1 | 正则引擎 | ✅ 用内置 `@string.Regex`（lexmatch 方言），规则正则统一改写；禁用 `\d\w\s\b` 与末尾裸 `-` |
| D3 | 哈希实现 | ✅ 用 `x/crypto/hmac` + `SHA256`，三后端一致已验证 |
| D7 | JSON 架构 | ✅ 文本轨为主 + 自建有序 AST（`Number(String)` + `Object(Array[...])`）为辅 |
| D8 | 结构轨深度 | ✅ v0.1 做最小 AST：路径定位 + 整字段替换 + 确定性序列化 |
| — | 金库 | v0.1 `tokenize`/`encrypt` 采用确定性 HMAC 令牌；AES-GCM 可逆金库延后 v1（无 GCM 原语） |
| — | native 产物 | ✅ 已用 MSVC Build Tools 2022 构建并验证；`scripts/msvc-env.sh` 自动导入 PATH / INCLUDE / LIB |

---

## 2. 落地范围（本次交付 = S1–S6 的实现 + S7 文档）

> 计划书的里程碑是按周排期的项目管理节奏；本次交付把 **S1–S6 的代码产物一次性落地**，并以 `moon check/test`（三后端）+ 一致性脚本验收。社区增长/发布（S7 的 mooncakes/npm 实际发布、S8 流式）不在本地代码交付范围内，文档中标明。

### 2.1 目录与产物

```
veil/
├── moon.mod / moon.pkg          # 模块名 veil，多包工程
├── spec/                        # 语言无关 JSON 规范（单一事实来源）
│   ├── entities.json            # 实体定义
│   ├── validators.json          # 校验器定义
│   ├── operators.json           # 算子定义
│   ├── schemas/                 # ruleset/testcase JSON Schema
│   └── test-cases/cases.json    # 跨后端一致性用例
├── core/                        # 后端无关内核
│   ├── span.mbt / rule.mbt / config.mbt / engine.mbt
│   ├── validator.mbt / operator.mbt / context.mbt / path.mbt
│   ├── jsonval.mbt / jsonparse.mbt / jsonwrite.mbt / format.mbt
│   └── *_wbtest.mbt             # 单元测试
├── crypto/                      # token.mbt（HMAC 令牌）/ vault.mbt
├── cli/                         # 原生产物（需 MSVC 构建）
├── js/                          # js (esm) 产物 + npm 打包元数据
├── wasm/                        # wasm / wasm-gc 产物
├── rules/                       # base.json / cn.json / secrets.json / headers.json
├── scripts/                     # consistency.sh / rules-lint.sh / build.sh
├── testdata/                    # 样本
├── README.md / CHANGELOG.md / LICENSE(Apache-2.0)
└── IMPLEMENTATION_PLAN.md       # 本文件
```

### 2.2 功能清单（对齐计划书 §4）

- **检测器 5 类**：`pattern`（lexmatch 正则）、`dictionary`、`field`、`composite`、`checksum`
- **算子 8 类**：`redact` / `replace` / `mask` / `hash` / `tokenize` / `encrypt`(HMAC 令牌) / `keep` /（custom 扩展点文档化）
- **校验器 10 个**：`luhn` / `cn_id_checksum` / `cn_bank_card_checksum` / `cn_uscc_checksum` / `isbn` / `imei` / `ipv4` / `ipv6` / `jwt` / `base64`
- **上下文打分**：words / anti_words / window / boost / penalty，命中不叠加取最高（确定性）
- **重叠消解**：分数>声明顺序>长 span（计划书 §4.7 四步）
- **fail-closed 策略**：`deny_by_default` + `allow_paths` / `ignore_paths`
- **路径匹配**：精确 / `*` 单层 / `*.suffix` 通配
- **JSON 双轨**：文本轨区间替换（默认，保序保精度）+ 有序 AST 结构轨（字段级）
- **审计报告**：只含类型/偏移/算子/规则版本，绝不含原值
- **规则加载**：JSON → schema/语义校验 → IR；错误即失败，不静默跳过

### 2.3 正则方言改写规则（全局强制）

| 常见写法 | lexmatch 写法 |
|---|---|
| `\d` | `[[:digit:]]` |
| `\w` | `[[:alpha:]]` / `[[:alnum:]]` / `[[:word:]]` |
| `\s` | `[[:space:]]` |
| `\b` 词边界 | 用前后向字符类或去掉（规则里避免依赖） |
| `[a-z-]`（末尾 `-`） | `[a-z\\-]` |
| `(?i)` | 用 `"flags": "i"` 交由引擎在匹配前 lower-case 处理 |

`rules-lint.sh` 检查：出现 `\d \w \s \b` 或字符类末尾裸 `-` 即报错。

---

## 3. 执行步骤

| 步骤 | 任务 | 验收 |
|---|---|---|
| S1 | 建 moon.mod + 各包 moon.pkg + spec/ 全部 JSON | `moon check` 三后端通过 |
| S2 | core：span/rule/config/path/context/validator/operator/engine | 单元测试通过 |
| S3 | core：jsonval/jsonparse/jsonwrite/format（双轨） | 保序/保数字/拒重复键测试通过 |
| S4 | crypto：token/vault；cli/js/wasm 入口 | 三后端构建 |
| S5 | rules/*.json 内置规则集 + spec/test-cases | lint 通过；cases 全部匹配 |
| S6 | scripts/consistency.sh 三后端逐字节比对 | 零差异 |
| S7 | README / CHANGELOG / LICENSE / 文档 | 完整可读 |

## 4. 一致性验收口径

计划书要求"四端逐字节一致"。2026-11-16 补齐 MSVC 后，**wasm / wasm-gc / js / native** 四端均可构建并运行：20 个测试 × 4 后端全部通过，6 条黄金用例在 JS ESM 产物与 native CLI 上分别逐字节一致。`spec/test-cases/cases.json` 中的固定密钥 HMAC 向量作为跨语言、跨后端的黄金基准。
