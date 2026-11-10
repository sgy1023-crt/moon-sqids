# MoonSqids 交接记录

2026 年 11 月 10 日（北京时间）。本地模块为 `sgy/moon-sqids@0.1.0`，独立 Git 仓库分支 `main`。`80d357b` 固定了公开 API 与工程文档，使用 `git log -1 --oneline` 查看包括本交接记录的当前提交。

## 实现

- 根包 `Sqids::new(alphabet?, min_length?, blocklist?)` 构造配置。 `Sqids::encode(ArrayView[Int64])` 与 `Sqids::decode(String)` 完成编解码。生成的 `pkg.generated.mbti` 列出完整公开接口。
- 编解码共用字符表旋转反转与洗牌。解码先验证整个 ID，再逐位检查溢出。错误分为 `ConfigError`、`EncodeError`、`DecodeError`。
- 官方默认 blocklist 560 词嵌入 MoonBit 常量。已逐条校对顺序及内容。库的运行时仅依赖 MoonBit 标准库，JavaScript 参考包只用于差分与互通示例。

## 实测记录

| 实际执行 | 结果 |
| --- | --- |
| `moon version --all` | `moon 0.1.20260904 (94521db)`，`moonc v0.10.12+1634b282e`，内置 core `0.10.12+1634b282e` |
| `moon test --target native,js --deny-warn` | 每后端 19 通过，0 失败，60 秒硬超时 |
| `moon info --target native,js`、`moon fmt --check`、`moon check --target native,js --deny-warn` | 退出码 0，生成的公开接口一致 |
| `moon build --target native,js --release --deny-warn` | 两个后端均构建成功 |
| `npm test --prefix tools/oracle` | 每后端 1915/1915 与官方 JS 0.3.0 匹配，0 差异 |
| `moon run --target <native 或 js> examples/record` 与 `examples/compound` | 两个示例在两个后端均还原输入 |
| `npm run interop --prefix tools/oracle` | JS → MoonBit 和 MoonBit → JS，两个后端各通过两条路径 |
| `python tools/check_package.py` | 重新打包、解压到外部临时工作区，独立项目两个后端各 1 通过，0 失败 |
| `moon package` | 生成 `_build/publish/sgy-moon-sqids-0.1.0.zip`。模块元数据包含公开 GitHub 仓库链接 |

开发期间，Windows 禁止创建模板 README 的符号链接，已改为普通 `README.md` 并验证打包。边界测试的错误捕获写法和示例的 `main` 错误声明经编译诊断修正后重跑通过。Wasm 和 LLVM 未运行。托管 CI 的状态以 GitHub Actions 为准。

## 申报和发布状态

- **初审技术材料齐备。** 表单可填写 [公开 GitHub 仓库](https://github.com/sgy1023-crt/moon-sqids)。参赛者本人撰写一页申报书及填写其他表单信息，组委会按规则核查有效提交。需核对当月截止、当前完成度对启动资助的影响和多项目口径。
- **完整本地工程 YES。** 包已验证可从归档安装使用。发布 Mooncakes 前确认拥有的命名空间，并按授权发布包。 `moon publish` 与实际赛事验收待执行。
- **可延期。** Wasm 或 LLVM 验证，以及 canonical 辅助 API，均为当前范围之外的可选工作。

[兼容性和固定版本](docs/COMPATIBILITY.md) · [赛事规则及待办](docs/HACKATHON.md)
