/** veil 0.1.0 — cross-platform PII & log redaction kernel (JS/ESM). */

export declare function version(): string;

/** 加载规则集的状态：空字符串表示成功，否则为分号分隔的错误描述。 */
export declare function load_ruleset_status(rules_json: string): string;

/**
 * 对文本脱敏。
 * @returns JSON 字符串 `{"text": string, "count": number}`；规则加载失败时 count = -1。
 */
export declare function redact_text(input: string, rules_json: string, key: string): string;

/** 确定性令牌 HMAC-SHA256(key, value) 的截断前缀。 */
export declare function tokenize(key: string, value: string, prefix: string, length: number): string;

/** HMAC-SHA256 → 小写十六进制（UTF-8 编码）。 */
export declare function hmac_sha256_hex(key: string, message: string): string;
