---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 1b41483b86e288ecb79c8a97a78d228d_23a8f870e1a211f1913b525400393706
    ReservedCode1: fJsJxp21VY/PkuxEU9fqd3pQoxHsvONyMaYP8Tw3UxvF3xY4k74Ag3ln5tAlwHN239QFNGLpYoQPtlGEhlxFJiIZ0gbWcwo5UWQPHQYZwr6DAGr/LhvFGBgEyMxrIj6zGx42qreo9NLnDivVtFHMM2eaFNZjwBjrGcaBZAtUy48TTcRoITatdXaE5cE=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 1b41483b86e288ecb79c8a97a78d228d_23a8f870e1a211f1913b525400393706
    ReservedCode2: fJsJxp21VY/PkuxEU9fqd3pQoxHsvONyMaYP8Tw3UxvF3xY4k74Ag3ln5tAlwHN239QFNGLpYoQPtlGEhlxFJiIZ0gbWcwo5UWQPHQYZwr6DAGr/LhvFGBgEyMxrIj6zGx42qreo9NLnDivVtFHMM2eaFNZjwBjrGcaBZAtUy48TTcRoITatdXaE5cE=
---

# Security Policy

## 设计前提

本工具只做一件事：让安装目录内的一个厂商标记文件无法被重写。它不接触游戏进程、内存、反作弊模块，也不修改任何可执行文件。所有写操作都限定在单一路径，且必须先备份。

## 安全边界

| 项 | 约定 |
| --- | --- |
| 目标路径 | 硬编码为 `<root>\TCLS\wegame_launch.tmp`，不接受外部传入 |
| 安装根校验 | 必须同时存在 `Game\League of Legends.exe` 与 `TCLS\Client.exe`，否则退出 40 |
| 路径穿越 | 含 `..` 的路径直接拒绝 |
| 备份位置 | `%LOCALAPPDATA%\LOLChainGuard\backup` |
| 提权 | 不申请管理员权限，不修改系统级配置 |
| 网络 | 无任何网络调用 |
| 注册表 | 只读取注册表用于定位安装根，不写入 |

## 不建议的使用方式

- 把 `--apply` 叠加进其它安装脚本批量执行而跳过备份检查；
- 手动把只读位或 ACL 施加到 `TCLS\Client.exe`、`Game\*.exe` 等可执行文件上——这会干扰游戏更新与反作弊初始化；
- 在非本人所有的设备上使用。

## 报告问题

若发现可实现以下效果的问题，请通过 Issue 私下说明，不要在公开 Issue 中贴出可直接利用的细节：

- 绕过白名单校验，使脚本对任意路径执行删除或 ACL 修改；
- 使 `--restore` 无法还原或损坏原始文件；
- 在无备份情况下发生不可逆写入。

请附：Windows 版本、目标盘文件系统、`lol-chain-probe.bat` 退出码、复现步骤。

## 非安全问题

以下不属于安全范畴，按普通 Issue 处理：WeGame 更新后重新接管、脚本在非中文路径下的兼容性、日志措辞建议。
*（内容由AI生成，仅供参考）*
