# Changelog

## v2.2.1 — 2026-11-16

修复两个"参数或文件名与预期不符"的问题。

### 修复

- **参数互斥不再静默降级**：`--apply` / `--restore` / `--link-only` / `--unlink` 互相组合时直接拒绝，输出 `result=REFUSED_CONFLICT` 并返回 44。v2.2.0 里 `--apply --relink` 会先命中链接分支（`LINKMODE=force` → `:do_link_only`），加锁步骤被整段跳过；`--apply --unlink` 同样会只删快捷方式不加锁。
- **快捷方式只有一个**：统一使用 `英雄联盟(原生客户端).lnk`（括号前不留空格）。v2.2.0 写入的是 `英雄联盟 (原生客户端).lnk`，与原图标并存就成了两个入口。现在创建前会清掉这个旧名残留，`--unlink` 也会一并删除。

### 新增

- 退出码 `44 = REFUSED_CONFLICT`。
- `--help` 补充互斥说明。

## v2.2.0 — 2026-11-16

WeGame 与原生快捷启动并存。

### Added
- **`--link-only`**：只创建/校验桌面原生快捷启动，不备份、不设只读、不加 ACL，完全不触碰 `TCLS\wegame_launch.tmp`，WeGame 启动链路保持原样。不需要确认，幂等（目标一致输出 `EXISTS_KEPT`）。
- `src/make_shortcut.ps1`：快捷方式逻辑从 bat 内联单行 `-Command` 抽出为独立脚本，bat 以 `-File` 调用；`-Root` 为空或路径不存在时自动回退注册表（Unicode 安全）读取安装根。

### Fixed
- `--link-only` 在 cmd 中稳定可用：此前 1.3 KB 的内联 `-Command` 从 bat 内执行会静默失败（`link=FAILED`），改为 `-File` 调用后实跑 `REPLACED` / `CREATED` / `EXISTS_KEPT` 均正常。
- `--link-only` 改为独立 `mode=link`，不再借用 dry-run 标志；`root_source` 变量名错误导致输出为空。

### Changed
- `--link-only` 与 `--apply` 的定位说明写入 README：加锁与双入口并存是两种取向，要两套入口长期可用请用 `--link-only`。

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
