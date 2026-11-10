# 兼容性与验证

## 对照基线

| 来源 | 固定标识 | 用途 |
| --- | --- | --- |
| [Sqids 规范](https://github.com/sqids/sqids-spec/tree/49b8ad8ea0725ee79c374ceb098cf100b52b0ec5) | `49b8ad8ea0725ee79c374ceb098cf100b52b0ec5` | 算法、编码步骤和解码语义 |
| [Sqids JavaScript](https://github.com/sqids/sqids-javascript/tree/0f0974ddd0aabb47c7e8399ec491f388a5df6f1f) | `sqids@0.3.0` / `0f0974ddd0aabb47c7e8399ec491f388a5df6f1f` | 官方向量、运行时差分预言机 |
| [官方 blocklist](https://github.com/sqids/sqids-blocklist/blob/084d15864ce0d102fd1aa0e752edb2d78e073e9f/output/blocklist.json) | `084d15864ce0d102fd1aa0e752edb2d78e073e9f` | 560 个默认词，顺序及内容与 JS 0.3.0 内置列表一致 |

上游 JSON 文件的 SHA-256 为 `757018526eaa1af57b9ccc9439fe672345b3ae85cf8162b74af45c0d6f5a9b1a`。仓库内将其转换为 MoonBit 常量，打包后无需读取文件或访问网络。 [许可与归属](../NOTICE.md)

## 行为

- 同一字符表、最小长度和有效 blocklist 产生与对照版本相同的编码。默认字符表区分大小写。自定义字符表接受三个及以上互不重复的 ASCII 字符，包括标点、空白和控制字符。
- 支持零、空序列、多整数与 `Int64` 表示的 `0..9007199254740991`。解码逐位检查 `number * radix + digit` 的上界再执行运算。官方 JS 对某些超范围 ID 会返回不安全的 Number，MoonSqids 改为抛出 `NumberOverflow`。
- `min_length` 是下界，范围 `0..255`。解码接受非规范 ID 和尾部填充，检查整个 ID 的字符合法性。空串和非法字符均按上游行为返回空数组。
- blocklist 在构造时转为小写，过滤短于三个字符和不能由当前字符表表达的词。三字符词全匹配，含 ASCII 数字的长词匹配两端，其他长词匹配子串。重试遍历所有不同的首字符后返回 `BlocklistExhausted`。JS 0.3.0 在耗尽时多检查一次初始候选，结果相同。
- 整数和最小长度使用静态整数类型。JavaScript 的小数、`NaN` 等动态输入不属于 MoonBit API 的参数域。兼容范围限于 Native 和 JavaScript，Wasm 与 LLVM 后端未运行。Hashids ID 没有迁移兼容保证。

blocklist 只影响编码结果。升级默认词表可能改变某些输入的新编码。需要长期保持输出稳定时，固定库版本和配置。使用相同字符表的旧 ID 仍可解码。

## 复现实测

`moon` 为 `0.1.20260904 (94521db)`，`moonc` 与 `moonbitlang/core` 为 `0.10.12+1634b282e`。Windows Node.js 为 `24.22.1`。

| 检查 | Native | JavaScript |
| --- | --- | --- |
| `moon test --target native,js --deny-warn` | 19 通过，0 失败 | 19 通过，0 失败 |
| `npm test --prefix tools/oracle` | 1915 匹配，0 差异 | 1915 匹配，0 差异 |
| `npm run interop --prefix tools/oracle` | 两条互通路径通过 | 两条互通路径通过 |
| `python tools/check_package.py` | ZIP 独立消费测试 1 通过 | ZIP 独立消费测试 1 通过 |

差分脚本用固定种子 `0x4d535149` 生成输入，逐项比较 10 组配置的编码和解码结果，以及无效配置和预期错误。脚本在失败时逐条打印后端、输入、预期和实际结果。每个后端限时 60 秒。复现前运行 `npm ci --prefix tools/oracle`。
