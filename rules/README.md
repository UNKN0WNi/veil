# 内置规则集

全部规则为**严格 JSON**，用 `"description"` 承载说明（JSON 无注释语法）。每条 detector 说明覆盖内容、典型误报与调整建议。

| 文件 | 覆盖 | 条数 |
|---|---|---|
| `base.json` | email / URL 凭据 / IPv4 / IPv6 / JWT | 5 |
| `cn.json` | 身份证 / 手机号 / 银行卡 / 统一社会信用代码 | 4 |
| `secrets.json` | AWS / GitHub / 私钥 / Slack / 通用 api_key | 5 |
| `headers.json` | HTTP 敏感头 / 密钥字段路径（field 类型） | 2 |

## 正则方言（重要）

veil 使用 MoonBit 内置 `lexmatch` 正则子集，四后端一致。规则正则**只能**使用共同支持的语法：

- ✅ POSIX 字符类 `[[:digit:]]` `[[:alpha:]]` `[[:alnum:]]` `[[:space:]]`
- ✅ 分组 `( )` `(?: )`、或 `|`、量词 `{n,m}`、断言 `^ $`、`.`
- ✅ 字符类内的字面 `-` 写作 `\\-`（JSON 中为 `\\-`）
- ❌ 禁用 `\\d` `\\w` `\\s` `\\b`（用 POSIX 类或去掉）
- ❌ 禁用 lookahead / 反向引用（四后端行为不一致）

`scripts/rules-lint.sh` 会自动检查禁用语法。

## 组合与版本

- `base.json` 的 `includes` 列出其余规则集；加载时可分别 `load_ruleset` 后合并 detectors。
- `rules_version` 会写入审计报告，便于溯源。
- 规则语义**只依赖数组顺序**，不依赖对象键顺序（detector 声明顺序用于重叠消解）。

## 误报调整

- 手机号裸数字歧义大 → 靠 `context.words` 提分；不需要时可提高 `min_score`。
- 通用 api_key 基线分低（0.3）→ 靠上下文词提分到阈值以上。
- 所有校验和型（身份证/银行卡/USCC）经 validator 过滤，误报率极低。
