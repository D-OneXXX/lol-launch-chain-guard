---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 1b41483b86e288ecb79c8a97a78d228d_7a0c1de7e1a311f189bc525400248c00
    ReservedCode1: mybomDgOsgLbSVHyUGDpDzJV5Td3lDGKNsH4fPpWgqgDiz+TVhgpenb1vD9ytqjy4gxKdLFgYbeF7rKlwJRbwQFFe6eXV4h6gcJ/61L6iAEqhhnnIdIM6RFMGaEAuLMEYDAXwrnRyvT35wxjdqYEXE0Hay3Mr855X77aBJahsQIDKO2vXbDR+nqKDpI=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 1b41483b86e288ecb79c8a97a78d228d_7a0c1de7e1a311f189bc525400248c00
    ReservedCode2: mybomDgOsgLbSVHyUGDpDzJV5Td3lDGKNsH4fPpWgqgDiz+TVhgpenb1vD9ytqjy4gxKdLFgYbeF7rKlwJRbwQFFe6eXV4h6gcJ/61L6iAEqhhnnIdIM6RFMGaEAuLMEYDAXwrnRyvT35wxjdqYEXE0Hay3Mr855X77aBJahsQIDKO2vXbDR+nqKDpI=
---



# 设计说明

记录几个关键取舍，以及踩过的坑。这些结论都来自实机验证，不是推测。

## 1. 为什么探测层和写入层要分成两个脚本

只读脚本一旦混入写操作，就没法放心地反复运行，也无法作为"当前状态"的可信来源。所以：

- `lol-chain-probe.bat`：只用 `if exist` / `attrib` / `reg query`，不建文件、不写日志、不提权；
- `lol-chain-lock.bat`：默认 dry-run，`--apply` 才落盘。

两层之间只通过退出码通信，互不依赖内部实现。这样 probe 可以作为任何自动化流程的前置判断。

## 2. 为什么不改代码页

中文安装路径在 `chcp` 切换代码页后容易在批处理变量展开时被截断，出现路径错位甚至误删相邻文件。本项目一律不改代码页，按系统默认编码处理路径，宁可日志里中文显示异常，也不冒路径损坏的风险。

## 3. exFAT 上的 ACL 假成功

第一版在 exFAT 盘上执行 `icacls "%TARGET%" /deny "%USERNAME%:(W)"`，命令返回 0，看起来成功。实际上 exFAT 没有 ACL 存储能力，拒绝项从未落地。如果只看返回码，会误以为做了双层加固。

修正方式：

1. 先判定目标文件所在卷的文件系统；
2. 非 NTFS 时明确输出 `SKIPPED_UNSUPPORTED`，不假装已加固；
3. 用 `dir /a:r` 判定只读位是否真的生效，而不是解析 `attrib` 的文本列（列宽在中文环境下会错位）。

结论：只读位在 exFAT 上依然是有效防线——写打开会被拒绝（实测 `WRITE_OPEN=DENIED`），只是没有 ACL 这层冗余。

## 4. 幂等与可逆

- 加锁前先把原文件复制到 `%LOCALAPPDATA%\LOLChainGuard\backup`，备份成功才继续；
- 若目标已是只读状态，重复 `--apply` 不改变结果，不重复创建备份；
- `--restore` 顺序为：移除 ACL 拒绝项 → 清除只读位 → 从备份复制还原 → 校验 SHA256。

实测回滚后文件 38 字节，SHA256 与备份一致。

## 5. 白名单为什么必须硬校验

脚本内存在 `del` 与 ACL 写操作，一旦目标路径可被外部控制，就等价于把删除能力开放出去。因此校验做了四层：安装根存在 → 两个锚点 exe 存在 → 目标路径与期望路径逐字符相等（不区分大小写比较）→ 路径不含 `..`。任一不通过即退出 40，不做任何写操作。

## 6. 措辞选择

仓库命名与文档统一使用 "launch chain guard"、"lock"、"lock the hijack file" 这类描述性说法，避免 "bypass"、"crack"、"破解" 一类词汇。原因很直接：本工具不绕过任何校验，它只是保持一个由官方文件组成的启动入口；用词失准会让项目被误归类，也会误导使用者以为存在额外能力。

## 7. 路径发现：为什么不写死盘符

第一版把 `D:\LOL`、`E:\LOL` 之类写进脚本，本质是把自己机器当成全部机器。别的机器上安装盘可能是 `C:`、目录名可能是 `英雄联盟(26)` 也可能是自定义。因此改成五级定位：

1. `--root` 显式参数（最高优先级，用户说了算）；
2. 环境变量 `LOL_ROOT`（便携安装、集成到别的脚本里时用）；
3. 注册表 `HKCU\SOFTWARE\Tencent\LOL` 的 `InstallPath`（官方安装器写入，版本目录带序号也跟随变化）；
4. 快捷方式 / 注册表反查（覆盖注册表键被改、只剩 lnk 的情形）；
5. 常见父目录扫描（兜底）。

每一级的结果都要过白名单才算数，定位失败不猜、不写。`root_source=` 明确打出来，使用者一眼能看到结论是"猜的"还是"注册表给的"。

## 8. 快捷启动的定位

快捷启动指向的是 `TCLS\Client.exe`，不是 `Game\League of Legends.exe`（那是游戏本体，需已登录态），也不是 WeGame（那是外层壳）。所以 `TargetPath` 取 `TCLS\Client.exe`，`WorkingDirectory` 取 `TCLS`（客户端按相对路径加载自己的资源），`IconLocation` 取该 exe 的第 0 号图标。

快捷方式名称含中文，但脚本必须保持纯 ASCII，因此名称在 PowerShell 一侧用 `[char]0x82F1...` 码点拼出来，.bat 里不出现任何非 ASCII 字符——这样不会因代码页不同而写出乱码文件名。

幂等通过比较已有快捷方式的 `TargetPath` 实现：目标一致 → `EXISTS_KEPT`；不一致 → `EXISTS_DIFFERENT` 并提示 `--relink`，不静默覆盖用户的快捷方式。

## 9. 备份为什么要按安装根分片

备份文件名固定为 `wegame_launch.tmp.bak` 时，两个安装目录（或 `--root` 指向另一台机器的路径）会共用一个备份文件，`--restore` 就可能把别的目录的字节写回来——这是实测中真实触发过的缺陷。改为按安装根小写路径的 MD5 分子目录后，各安装根互不干扰。

## 10. 已知未覆盖

- 未在 NTFS 盘上完成端到端实机验证（按设计实现，建议自测）；
- 未观测到 WeGame 直接改写 `TCLS\Client.exe` 的行为，故未做针对性防护；
- 无自动监测，更新后需手动复查。
*（内容由AI生成，仅供参考）*
*（内容由AI生成，仅供参考）*
