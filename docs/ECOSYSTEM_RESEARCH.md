# MoonSqids 生态查重

检索日期为 2026 年 11 月 10 日（北京时间）。在本次覆盖的公开来源中，未找到成熟、直接兼容 Sqids 的 MoonBit 工具库。结果支持继续开发独立移植，适用范围限于下列检索。

## 检索范围与结果

| 来源 | 实际核查 | 结果 |
| --- | --- | --- |
| GitHub 仓库搜索 REST API | `sqids moonbit`、`MoonSqids`、`sqids-mbt`、`hashids moonbit`、`reversible short ID moonbit`、`sqids language:MoonBit`、`hashids language:MoonBit`、`sqids in:readme language:MoonBit`、`hashids in:readme language:MoonBit`、`sqids topic:moonbit` | 各返回 0 条，`incomplete_results=false`。 |
| GitHub README 与议题搜索 | 仓库查询 `reversible short ID in:readme language:MoonBit`，议题及 PR 查询 `sqids moonbit in:title,body` | 前者有两个候选，分别是日志脱敏和静态分析项目。后者返回 0 条。 |
| Mooncakes 注册表 | 下载 `/api/v0/modules/all`，对当时 3,695 个模块的名称、描述和关键词做不区分大小写匹配，词为 `sqids`、`hashids`、`nanoid`、`reversible short id` | 命中 `hustcer/nanoid@0.6.1` 和 `ledao/nanoid@0.2.1`，均为 NanoID。 |
| Mooncakes 命令行搜索 | 用 `moon search <词> --json` 检索 `Sqids`、`MoonSqids`、`sqids-mbt`、`Hashids`、`NanoID`、`reversible short ID` | `Sqids` 的唯一模糊匹配是 `bobzhang/games@0.9.33`。查看其模块树，内容为游戏及相关示例，未见 Sqids 公开接口。其余关键词也未发现直接候选。 |
| Sqids 官方实现列表 | 查看 Sqids 官网语言列表，并检查 Sqids GitHub 组织 API 返回的 55 个公开仓库的名称、描述和语言 | 未列出 MoonBit 实现。 |

查询入口可复查。 [GitHub 仓库查询](https://github.com/search?q=sqids+language%3AMoonBit&type=repositories) · [GitHub 议题查询](https://api.github.com/search/issues?q=sqids+moonbit+in:title,body) · [Mooncakes 模块索引](https://mooncakes.io/api/v0/modules/all) · [Sqids 官网](https://sqids.org/) · [Sqids 组织公开仓库](https://api.github.com/orgs/sqids/repos?per_page=100)

检索后核对了模糊候选的模块说明和公开接口。`redact-mbt` 做输出脱敏，README 将可逆掩码列在范围外。`moonbit_static_analysis` 提供程序与状态机静态分析。`bobzhang/games` 列出游戏与演示包。 [redact-mbt](https://github.com/Guan0310/redact-mbt) · [moonbit_static_analysis](https://github.com/riantr/moonbit_static_analysis) · [bobzhang/games@0.9.33](https://mooncakes.io/docs/bobzhang/games@0.9.33)

## 相邻能力与项目增量

| 方案 | 接口或算法契约 |
| --- | --- |
| MoonBit NanoID | 根据长度和字符表生成随机字符串。公开接口支持随机源配置，未提供从 ID 还原输入整数序列的契约。 |
| Hashids | 同样能把数字映射为短 ID。Sqids 改变了字符表洗牌和分隔符规则，并加入 blocklist，旧 Hashids 输出不能当作 Sqids 兼容凭据。 |
| 普通进制转换 | 将整数映射到指定基数的数字字符。Sqids 还定义了字符表旋转、位置分隔符、序列编码、填充和屏蔽词重试。 |
| MoonSqids | 在 MoonBit 内按 Sqids 规则编码和解码整数序列。与其他语言使用相同配置时，可交换数据库记录 ID、复合定位参数和跨语言传递的短 ID。 |

[NanoID Mooncakes API](https://mooncakes.io/docs/hustcer/nanoid@0.6.1) · [NanoID 第二个移植的仓库](https://gitee.com/ledao/nanoid) · [Sqids 规范及 Hashids 差异](https://github.com/sqids/sqids-spec#-improvements-over-hashids)

## 证据边界

仓库查询覆盖公开索引的仓库元数据和 README，Mooncakes 全量接口覆盖发布模块的元数据。两者都无法覆盖未公开仓库、未发布模块或藏在通用包内且未写入可检索信息的实现。Sqids 官网列出的是官方实现，社区移植可能未登记。

本次检索支持“尚未找到直接同类”的结论。真实用户需求、采用量和报名资格尚未验证。项目新颖性与参赛资格最终以组委会的当月规则和审核为准。
