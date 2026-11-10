# 与官方 JavaScript 实现互通

示例使用虚构的租户、分区和记录编号。JavaScript 调用 `sqids@0.3.0` 编码 `[7, 3, 12345]`，MoonBit 解码其输出。MoonBit 再编码 `[12345, 9007199254740991]`，JavaScript 解码并校验两个值。

在仓库根目录运行以下命令。第二条命令会分别运行 MoonBit Native 和 JavaScript 后端。

```sh
npm ci --prefix tools/oracle
npm run interop --prefix tools/oracle
```

交互示例使用 `MOONSQIDS_INTEROP_BATCH` 传输 JSON 请求数组。每个请求可带 `alphabet`、`min_length` 和 `blocklist`，并在 `numbers` 和 `id` 中二选一。MoonBit 的 `Int64` 通过十进制字符串传输。

```json
[{"id":"RMeyNPxf"},{"numbers":["12345","9007199254740991"]}]
```

`main.mbt` 只调用库的公开 API。`tools/oracle/interop.mjs` 调用真实 JavaScript 包并验证两条传输路径。
