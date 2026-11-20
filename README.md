# MoonSqids

MoonSqids 将一个或多个非负整数编码为可逆短 ID。它用 MoonBit 实现 [Sqids 规范](https://github.com/sqids/sqids-spec)，适用于公开链接里的记录编号、由多个整数构成的定位参数，以及与其他语言服务交换短 ID。

MoonSqids is a MoonBit port of Sqids for reversible short IDs. It also supports versioned public links, staged configuration changes and offline migration. The MoonBit library supports Native and JavaScript with no third-party runtime dependencies.

NanoID 生成随机字符串。Hashids 有自己的编码格式。普通进制转换处理单个整数。MoonSqids 实现了 Sqids 的多整数分隔、字符表轮换、最小长度填充和屏蔽词重试。 [生态查重与对照](docs/ECOSYSTEM_RESEARCH.md)

## 在另一个 MoonBit 项目中使用

通过 Mooncakes 安装固定版本。 [MoonSqids 0.2.0](https://mooncakes.io/docs/sgy1023-crt/moon-sqids@0.2.0)

```sh
moon add sgy1023-crt/moon-sqids@0.2.0
```

如果要开发本地源码，将 `moon-sqids/` 与你的 `app/` 放在同一工作区，然后在上一级创建 `moon.work`。

```moonbit
members = ["app", "moon-sqids"]
```

本地工作区也需要在 `app/moon.mod` 中声明相同的模块依赖。

```moonbit
import {
  "sgy1023-crt/moon-sqids@0.2.0",
}
```

在使用它的 `moon.pkg` 中导入根包。

```moonbit
import {
  "sgy1023-crt/moon-sqids" @sqids,
}
```

## 编解码

```moonbit
fn main raise {
  let codec = @sqids.Sqids::new()
  let id = codec.encode([1L, 2L, 3L]) // "86Rf07"
  let numbers = codec.decode(id)     // [1L, 2L, 3L]
  assert_eq(numbers, [1L, 2L, 3L])
}
```

同一配置可以重复使用。构造函数接受三个可选参数，可按需组合。

```moonbit
let padded = @sqids.Sqids::new(min_length=10)
// padded.encode([1L, 2L, 3L]) => "86Rf07xd4z"

let shuffled = @sqids.Sqids::new(
  alphabet="FxnXM1kBN6cuhsAvjW3Co7l2RePyY8DwaU04Tzt9fHQrqSVKdpimLGIJOgb5ZE",
)
// shuffled.encode([1L, 2L, 3L]) => "B4aajs"

let filtered = @sqids.Sqids::new(blocklist=["86Rf07"])
// filtered.encode([1L, 2L, 3L]) => "se8ojk"
```

- 数字类型为 `Int64`，支持 `0..9007199254740991`，包含端点。空序列编码成空串。
- 字符表至少有三个互不重复的 ASCII 字符，区分大小写。默认字符表是 URL 友好的字母和数字。自定义字符表若含 URL 保留字符，放入 URL 前需转义。
- `min_length` 支持 `0..255`，默认 0。编码超过该值时保留实际长度。
- 省略 `blocklist` 使用完整官方默认列表。传入自定义列表会替换默认列表，`blocklist=[]` 关闭匹配。改变列表可能改变编码结果。解码仍可读出同字符表产生的旧 ID。
- `ConfigError` 报告无效配置，`EncodeError` 报告数字越界或屏蔽词重试耗尽，`DecodeError` 报告解码数字溢出。空 ID 或含字符表外字符的 ID 解码为 `[]`。一个序列可能有多个可解码 ID。

短 ID 可逆，不能用于加密、哈希、身份验证、授权或数据保护。 [Sqids FAQ](https://sqids.org/faq)

## 公开链接升级与迁移

如果已对外发出短链接，可以使用 `sgy1023-crt/moon-sqids/migration` 固定各版本的字符表、最小长度和屏蔽词，并约束 ID 中各整数字段的范围。读端可同时识别历史链接和带版本的新链接。写端切换前可以检查读端是否已经认识新配置。

```sh
moon build cmd/bridge --target js --release --deny-warn
node cmd/moonsqids.mjs plan examples/rollout/manifest.json examples/rollout/ids.txt migration-report.jsonl
```

示例中的 `A6da` 迁移为 `v2~Atbx25UEDm`，二者定位同一条记录。命令按行输出映射及错误原因，报告写完后才出现目标文件。SDK 支持 Native 和 JS，命令行与 HTTP 示例用 Node.js 24 运行。 [部署、复现与文件格式](examples/rollout/README.md)

## 三个运行示例

```sh
moon run --target native examples/record
moon run --target js examples/compound
npm ci --prefix tools/oracle
npm run interop --prefix tools/oracle
```

1. 数据库记录编号 `12345` 编码为 `A6da`，再解回 `12345`。 [代码](examples/record/main.mbt)
2. 将租户 `7`、分区 `3`、记录 `12345` 打包成 `/records?locator=RMeyNPxf`，再解出三个编号。 [代码](examples/compound/main.mbt)
3. 官方 JavaScript 包与 MoonBit Native、JS 后端互相编码和解码，示例覆盖最大安全整数。 [代码与运行方式](examples/interop/README.md)

## 检查、测试与打包

已验证工具链为 `moonc v0.10.12+1634b282e`。差分测试使用 Node.js 24 和锁定的 `sqids@0.3.0`。Python 3 用于从发布 ZIP 验证独立消费者。

```sh
moon test --target native,js --deny-warn
moon fmt --check
moon check --target native,js --deny-warn
moon build --target native,js --release --deny-warn
npm ci --prefix tools/oracle
npm test --prefix tools/oracle
python tools/check_package.py
node tools/check_record_rollout.mjs
node tools/check_migration_cli.mjs
moon package
```

要验证注册表下载安装，在仓库根目录运行 `python tools/check_package.py --registry`。脚本在独立工程中从 Mooncakes 安装固定版本，并在 Native 和 JavaScript 上验证编解码与迁移。

本项目为 2026 年 11 月 MoonBit 黑客松新项目准备。项目与上游数据采用 MIT 许可，来源和固定版本见 [NOTICE.md](NOTICE.md)。实测与兼容边界见 [COMPATIBILITY.md](docs/COMPATIBILITY.md)，赛事核对见 [HACKATHON.md](docs/HACKATHON.md)。
