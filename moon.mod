// veil — 跨端 PII 与日志脱敏内核
//
// 这个文件只描述「模块身份」和依赖，不描述构建目标：
// 目标由命令行决定（moon build --target wasm|wasm-gc|js|native）。
// 改模块名 / 版本 / 依赖，只改这一处。字段含义见 https://www.moonbitlang.com/docs

// 模块名，也是源码里 @veil/... 的包前缀，改名会牵动所有 import。
name = "veil"

// 语义化版本。发布到 mooncakes 时用它，JS 包版本在 js/package.json 里单独维护。

version = "0.1.0"

// 许可证，需与仓库根的 LICENSE 一致。

license = "Apache-2.0"

// 一句话介绍，会显示在 mooncakes 的模块页面上。

description = "Cross-platform PII & log redaction kernel: one declarative JSON ruleset, byte-identical across backends"

// 仓库地址，mooncakes 用它生成源码链接。

repository = "https://github.com/UNKN0WNi/veil"

// 检索关键词，影响别人在 mooncakes 上搜到你的概率。

keywords = [ "pii", "redaction", "masking", "privacy", "log-scrubbing" ]

// 模块主页显示哪份 README；本项目是中文版，英文版见 README.en.md。

readme = "README.md"

// 第三方依赖清单。只有 crypto 包用到 x/crypto 的 SHA-256 与 HMAC，
// 四个后端取同一份实现，所以哈希结果逐字节一致。
// 想换版本或加依赖，只改这里；core 包本身只依赖 moonbitlang/core，保持后端无关。
import {
  "moonbitlang/x@0.5.7",
}
