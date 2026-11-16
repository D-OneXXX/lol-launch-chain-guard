---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 1b41483b86e288ecb79c8a97a78d228d_24ddc99be1a211f1913b525400393706
    ReservedCode1: op7+n2PuVG6iGV3eb5uZNEpxNTuKdm1tK1/znjDcB7oQVq60vLSN5wvqdkZ+JLWn1z/KPkwWrujbczdijEwpW4y9GdKUexzKYQhtHmDWpS7zjByLamztjBpz97HZLf05drrJwW6Tp6Y6B9DaXi9+2UhmQM3dUjxLarnnXB4Yvg8zVK3MrHzwZPTps/w=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 1b41483b86e288ecb79c8a97a78d228d_24ddc99be1a211f1913b525400393706
    ReservedCode2: op7+n2PuVG6iGV3eb5uZNEpxNTuKdm1tK1/znjDcB7oQVq60vLSN5wvqdkZ+JLWn1z/KPkwWrujbczdijEwpW4y9GdKUexzKYQhtHmDWpS7zjByLamztjBpz97HZLf05drrJwW6Tp6Y6B9DaXi9+2UhmQM3dUjxLarnnXB4Yvg8zVK3MrHzwZPTps/w=
---

# Changelog

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
