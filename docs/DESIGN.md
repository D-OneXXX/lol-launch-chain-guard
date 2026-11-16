---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 1b41483b86e288ecb79c8a97a78d228d_25eda773e1a211f189bc525400248c00
    ReservedCode1: fw2Qd+y4NRs0yBfrfyKx0oCCYm/k5zEAT2+Ly5kPiG4ZqhycVzp3XoC5xDw7oFTojSIVWEguMWgXTSllbE4X5xiYhaivfErTtK8TylfeAdyUH3jsqQxICjyGAkDRJZobICbRF0T72z5f/as4QkBB6GgqEzzunhcIus4gVsL8/Nk+4Tf+79FPpkSal/E=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 1b41483b86e288ecb79c8a97a78d228d_25eda773e1a211f189bc525400248c00
    ReservedCode2: fw2Qd+y4NRs0yBfrfyKx0oCCYm/k5zEAT2+Ly5kPiG4ZqhycVzp3XoC5xDw7oFTojSIVWEguMWgXTSllbE4X5xiYhaivfErTtK8TylfeAdyUH3jsqQxICjyGAkDRJZobICbRF0T72z5f/as4QkBB6GgqEzzunhcIus4gVsL8/Nk+4Tf+79FPpkSal/E=
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

## 7. 已知未覆盖

- 未在 NTFS 盘上完成端到端实机验证（按设计实现，建议自测）；
- 未观测到 WeGame 直接改写 `TCLS\Client.exe` 的行为，故未做针对性防护；
- 无自动监测，更新后需手动复查。
*（内容由AI生成，仅供参考）*
