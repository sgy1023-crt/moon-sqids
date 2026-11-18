# 升级公开记录链接

记录服务和批量命令都通过 MoonBit 解析同一份配置清单。示例将旧字符表生成的 `A6da` 迁移为 `v2~Atbx25UEDm`，两者都定位记录 `12345`。

需要仓库 README 中的 MoonBit 工具链和 Node.js 24。在仓库根目录运行：

```sh
moon build cmd/bridge --target js --release --deny-warn
node examples/rollout/server.mjs examples/rollout/manifest.json
```

服务监听 `127.0.0.1:8080`。访问 `/records/A6da` 和 `/records/v2~Atbx25UEDm` 可查看同一条记录。访问 `/record-links/12345` 获取当前版本的链接。未知版本、不符合字段约束的 ID 和不存在的记录均返回 HTTP 404。

运行自动验证可以重现部署前、读端加入新版本、写端切换三个阶段。

```sh
node tools/check_record_rollout.mjs
node tools/check_migration_cli.mjs
```

## 部署与迁移

1. 为新字符表或新的最小长度、屏蔽词新增 profile。保留已发行版本的全部配置。用 `check-upgrade` 比较实际部署的配置与候选配置。
2. 在读端部署包含新 profile 的配置，写端仍使用原版本。确认所有读端都已更新后，用 `check-issuer` 比较已部署读端和准备使用的写端配置，再切换 `current`。如果写端要回退，保留两个 profile，只切换当前发行版本。
3. 导出历史 ID，一行一条。批量命令生成 JSONL 对照报告，包含行号、源版本、目标 ID 和整数序列，或每条失败的原因。核对结果后按业务流程应用映射。

```sh
node cmd/moonsqids.mjs check-upgrade deployed.json candidate.json
node cmd/moonsqids.mjs check-issuer readers.json writer.json
node cmd/moonsqids.mjs plan examples/rollout/manifest.json examples/rollout/ids.txt migration-report.jsonl
```

示例输入含两个拒绝项，所以批量命令生成完整报告后返回退出码 2。退出码 0 表示全部接受，退出码 1 表示命令、配置或文件操作失败。报告路径须是新文件，所在文件系统须支持硬链接，例如 NTFS 或 ext4。命令流式读取 UTF-8 文本，支持 LF 和 CRLF，超过 4096 字节的行单独报告。进程强制停止时，目标目录可能留有 `.moonsqids-*` 临时目录，确认对应任务结束后可清理。重跑可以继续使用尚未生成的目标路径。

`fields` 定义按顺序编码的必填整数分量，每个分量包含名称和上下界，`min` 与 `max` 用十进制字符串。每份清单定义一个业务 ID 域，最多 64 个字段。`legacy` 是无版本历史链接的唯一配置。`profiles[].blocklist` 要填写确切的历史列表，示例使用空数组。线上使用时须保留历史实际用过的字符表、长度和词表。来自同一套配置的规范 ID 才通过严格验证。

短 ID 是可逆标识。示例用合成记录验证路由行为，业务应用应继续校验记录是否存在及访问者权限。
