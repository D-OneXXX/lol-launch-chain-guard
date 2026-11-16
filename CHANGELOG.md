---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 1b41483b86e288ecb79c8a97a78d228d_782415a5e1a311f1913b525400393706
    ReservedCode1: tdvFopTVKCp9t3aq7OJWmDKNqrABFKneWbBRNedAoQOLKeHN0MYM18F61Qah1xB9YTf3b1AiYTxmLq2Mm9d6TaARKzUiAFgUzRoDBtJ0rt4O4Z1dH/ICBm4axlsjxE+d2CFFz3PqQ0t4y5OhfAYx8arADV7FIaCDhO8A0fnTcRtiswatdX5LdNOYab0=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 1b41483b86e288ecb79c8a97a78d228d_782415a5e1a311f1913b525400393706
    ReservedCode2: tdvFopTVKCp9t3aq7OJWmDKNqrABFKneWbBRNedAoQOLKeHN0MYM18F61Qah1xB9YTf3b1AiYTxmLq2Mm9d6TaARKzUiAFgUzRoDBtJ0rt4O4Z1dH/ICBm4axlsjxE+d2CFFz3PqQ0t4y5OhfAYx8arADV7FIaCDhO8A0fnTcRtiswatdX5LdNOYab0=
---



# Changelog

## v2.1.0 — 2026-11-16

跨机器可用性 + 原生快捷启动。

### Added
- **安装根自适应定位**：`--root` > `LOL_ROOT` > 注册表 `HKCU\SOFTWARE\Tencent\LOL` > lnk / 注册表反查 > 常见父目录扫描，五个定位源按序命中即停，输出 `root_source=` 标明来源。不再写死盘符与目录名。
- **桌面原生快捷启动**：`--apply` 同步在桌面创建「英雄联盟 (原生客户端)」快捷启动，目标 `<root>\TCLS\Client.exe`、工作目录 `TCLS`、图标取自该 exe（不是文件夹，也不是 WeGame）。
- `--relink` 强制重建、`--unlink` 只删快捷启动、`--apply --no-link` 只加锁。
- 同名快捷启动目标不一致时输出 `EXISTS_DIFFERENT` 并提示 `--relink`，不静默覆盖。

### Changed
- 备份路径改为 `%LOCALAPPDATA%\LOLChainGuard\backup\<安装根MD5>\`，多安装目录 / 跨机器不会共用同一备份，`--restore` 无法写回别的目录的字节。

### Verified
- 隔离环境全链路实跑：`link=CREATED` → 二次 `EXISTS_KEPT`（幂等）→ `--unlink` 删除 → `--restore` 还原，文件内容回到原始字节。
- 注册表自动定位在中文、带括号版本目录下命中并返回退出码 0。
- `--root` 传入含空格与括号的中文路径解析正确。

## v1.0.0 — 2026-11

首个可用版本。

### Added
- `src/lol-chain-probe.bat`：只读探测启动链，退出码 0 / 10 / 20 / 30。
- `src/lol-chain-lock.bat`：写入层，默认 dry-run；支持 `--apply`、`--apply --purge`、`--restore`、`--yes`。
- 硬白名单校验：目标必须为 `<root>\TCLS\wegame_launch.tmp`，且安装根含 `Game\League of Legends.exe` 与 `TCLS\Client.exe`。
- 写入前自动备份至 `%LOCALAPPDATA%\LOLChainGuard\backup`。
- 按文件系统分级加锁：NTFS 只读位 + ACL deny 双层；exFAT / FAT32 仅只读位，并明确输出 `SKIPPED_UNSUPPORTED`。
- 文档：README、SECURITY、docs/DESIGN、LICENSE（MIT）。

### Verified
- 国服原生启动链成立：`TCLS\Client.exe` 自带 QQ / 微信登录界面。
- 只读位可拒绝写句柄：`WRITE_OPEN=DENIED`。
- `--restore` 后文件 SHA256 与备份一致（38 字节）。
- 目视确认双击快捷方式弹出原生 TCLS 登录框，未被 WeGame 接管。

### Known issues
- exFAT 上 `icacls /deny` 返回成功但无实际效果，已按文件系统分支规避。
- NTFS 分支未完成端到端实机验证。
- 国际服不支持，2026 起强制经 Riot Client 启动。
*（内容由AI生成，仅供参考）*
*（内容由AI生成，仅供参考）*
