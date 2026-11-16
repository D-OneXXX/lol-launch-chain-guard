# LOL Launch Chain Guard

Windows 批处理工具，用于让《英雄联盟》国服保持以**原生 TCLS 登录器**启动，并防止 WeGame 在版本更新后把启动链重新接管回壳内。

> **性质声明**：本项目只处理厂商在安装目录写入的启动链标记文件，不修改游戏本体，不读写进程内存，不注入、不 Hook、不触碰 ACE 反作弊组件。它管理的是"从哪个入口启动"这一偏好，不是绕过任何登录校验或付费校验。

---

## 结论先行（2026-11 实测）

| 客户端 | 原生启动 | 说明 |
| --- | --- | --- |
| 国服（腾讯） | ✅ 可用 | `<root>\TCLS\Client.exe` 自带 QQ / 微信登录界面，WeGame 只是外层封装 |
| 国际服 | ❌ 不可用 | 2026 起客户端强制经 Riot Client 启动，无原生登录器可直连 |

网上流传的 `--no-launcher`、`-nolauncher` 一类启动参数经实测**不存在**，不要采信。

---

## 它做什么，不做什么

| 做 | 不做 |
| --- | --- |
| 探测启动链是否仍为原生（只读） | 不修改 `Game\League of Legends.exe` |
| 锁定 WeGame 的启动链标记文件 | 不修改 `TCLS\Client.exe` |
| 备份原始文件，可一键回滚 | 不写注册表、不改启动项 |
| 按文件系统自动降级加锁策略 | 不联网、不上传任何数据、不需管理员权限 |
| 全程默认 dry-run，写操作需显式 `--apply` | 不卸载、不禁用 WeGame 本体 |

---

## 原理

启动链实际有三层：

```
桌面快捷方式
   └─> <root>\TCLS\Client.exe        （原生壳，带腾讯登录界面）
         └─> <root>\Game\League of Legends.exe
```

WeGame 并不需要替换任何 exe，它只需在 `TCLS` 目录写入一个标记文件 `wegame_launch.tmp`，表示"这次启动由我发起"，随后把自己插入链路。因此：

- 该文件**存在且可写** → WeGame 有把握重新接管启动；
- 该文件**只能在无写入句柄的情况下被创建** → 壳退回原生登录界面。

工具做的事就是让这个标记文件无法被重写。注意它不是一次性设置：WeGame 自检、游戏大版本更新都可能把它写回来，所以需要可重复执行的加锁与复查。

---

## 快速开始

```bat
:: 1. 只读探测：当前链路是否原生
src\lol-chain-probe.bat

:: 2. 干跑：只打印计划，不写任何东西
src\lol-chain-lock.bat

:: 3. 加锁
src\lol-chain-lock.bat --apply

:: 4. 回滚到原始状态
src\lol-chain-lock.bat --restore
```

然后把桌面快捷方式指向 `<root>\TCLS\Client.exe`（不是 WeGame，也不是 `Game\League of Legends.exe`）。

### 参数

| 参数 | 作用 |
| --- | --- |
| 无 | dry-run，仅打印将要执行的动作 |
| `--apply` | 保留原文件，设置只读位 + 拒绝当前用户写入 |
| `--apply --purge` | 删除原文件后放置 0 字节占位文件，再执行加锁 |
| `--restore` | 移除 ACL 拒绝项、清除只读位、从备份还原原文件 |
| `--yes` | 跳过交互确认（供脚本 / CI 使用） |

### 退出码

`lol-chain-probe.bat`

| 码 | 含义 |
| --- | --- |
| 0 | `NATIVE_OK` 原生登录器存在，链路完整 |
| 10 | `SHELL_ONLY` 只有 WeGame 壳，无原生登录器 |
| 20 | `PARTIAL` 目录结构不完整 |
| 30 | `NOT_FOUND` 未定位到安装根 |

`lol-chain-lock.bat`

| 码 | 含义 |
| --- | --- |
| 0 | `OK` |
| 40 | `REFUSED_WHITELIST` 白名单校验不通过，拒绝执行 |
| 41 | `NOT_INSTALLED` 未定位到有效安装根 |
| 42 | `DRYRUN_ONLY` 干跑结束，未写入 |
| 43 | `PARTIAL` 部分步骤失败，可用 `--restore` 回滚 |

---

## 文件系统分级（关键）

加锁强度取决于目标磁盘的文件系统，这是本项目最容易被误判的地方：

| 文件系统 | 只读属性位 | `icacls` 拒绝写入 | 实际防护 |
| --- | --- | --- | --- |
| NTFS | 有效 | 有效 | **双层**：只读位 + ACL deny |
| exFAT | 有效 | **假成功**（命令返回 0，实际不生效） | **单层**：仅靠只读位拒绝写入句柄 |
| FAT32 | 有效 | 假成功 | 单层 |

实测结论：在 exFAT 上 `icacls /deny` 返回成功码却不产生任何拒绝项，脚本因此按文件系统分支处理，非 NTFS 时明确输出 `SKIPPED_UNSUPPORTED`，而不是伪装成已加固。只读位本身足以让写打开失败（实测 `WRITE_OPEN=DENIED`），所以单层仍然有效，只是少了一道冗余。

---

## 更新后怎么办

游戏大版本更新或 WeGame 自身更新，都可能重置该目录：

1. 更新前执行 `--restore`，避免安装器因写入失败中断；
2. 正常更新；
3. `lol-chain-probe.bat` 复查退出码；
4. 必要时重新 `--apply`。

如果哪天 WeGame 又开始接管，看 `TCLS\wegame_launch.tmp` 是否存在、是否可写即可定位。

---

## 安全边界

- **硬白名单**：只接受 `<root>\TCLS\wegame_launch.tmp` 这一精确路径，且要求 `<root>` 下同时存在 `Game\League of Legends.exe` 与 `TCLS\Client.exe`。任何路径参数不匹配、路径含 `..` 直接拒绝（退出码 40）。
- **拒绝路径穿越**：不接受用户自选目标。
- **必须先备份**：原始文件复制到 `%LOCALAPPDATA%\LOLChainGuard\backup` 后才允许写操作。
- **幂等**：重复执行结果一致，不会叠加或损坏。
- **可逆**：`--restore` 后 SHA256 与备份一致。
- **无需提权**：不申请管理员，不修改系统级设置。

---

## 验证记录

| 项目 | 结果 |
| --- | --- |
| `lol-chain-probe.bat` 本机实跑 | 退出码 0（`NATIVE_OK`） |
| 只读位对写句柄的拦截 | `WRITE_OPEN=DENIED` |
| exFAT 上 `icacls /deny` | 返回 0 但无实际拒绝项 → 判为单层，输出 `SKIPPED_UNSUPPORTED` |
| `--restore` 完整性 | SHA256 与备份一致，文件 38 字节 |
| 目视验证 | 双击指向 `TCLS\Client.exe` 的快捷方式，弹出原生 TCLS 登录框，未被 WeGame 接管 |

---

## 已知限制

- 仅在中文国服、Windows 11（Build 26200）、目标盘为 exFAT 的环境完成验证；NTFS 分支为按设计实现，建议自测后使用。
- 只读位可被管理员或安装程序清除，这是文件系统的固有属性，不是脚本缺陷。
- 不处理 WeGame 通过其他途径接管的情形（当前版本未观测到）。
- 不做自动监测/自愈，需手动或配合计划任务复查。

---

## 目录结构

```
lol-launch-chain-guard/
├─ src/
│  ├─ lol-chain-probe.bat   只读探测层
│  └─ lol-chain-lock.bat    写入层（dry-run 默认）
├─ docs/
│  └─ DESIGN.md             设计取舍与踩坑记录
├─ .github/
│  ├─ ISSUE_TEMPLATE/bug_report.yml
│  ├─ pull_request_template.md
│  └─ workflows/checks.yml  bat 行尾 / 编码 / 安全守卫静态校验
├─ SECURITY.md
├─ CHANGELOG.md
├─ LICENSE
└─ README.md
```

设计上探测层与写入层严格分离，中间只通过退出码通信：只读脚本永远不写盘，可以随便跑。

## License

MIT，见 [LICENSE](LICENSE)。
