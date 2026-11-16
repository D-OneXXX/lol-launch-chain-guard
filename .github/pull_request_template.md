---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 1b41483b86e288ecb79c8a97a78d228d_7b2855d3e1a311f189bc525400248c00
    ReservedCode1: KtKj4e7hHGfNvQxOOGhuy9WQBowIlqzuqIqzxeQC4XD/lB4EZikEbK4IM5XNW90SyUeU28cpav9rDaWnCSw1Rd4FzQC2zuNLumy/8dUdBivN7zF8NHXJn5TS2oqs3kdhItF6h+mUc+LiXi/pImsY4Xgp9uPuwFOhp/X/8TL5/0HsyjAIT6L+CleEOoo=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 1b41483b86e288ecb79c8a97a78d228d_7b2855d3e1a311f189bc525400248c00
    ReservedCode2: KtKj4e7hHGfNvQxOOGhuy9WQBowIlqzuqIqzxeQC4XD/lB4EZikEbK4IM5XNW90SyUeU28cpav9rDaWnCSw1Rd4FzQC2zuNLumy/8dUdBivN7zF8NHXJn5TS2oqs3kdhItF6h+mUc+LiXi/pImsY4Xgp9uPuwFOhp/X/8TL5/0HsyjAIT6L+CleEOoo=
---

# 改动说明

一句话说明这个 PR 改了什么，为什么。

## 类型

- [ ] 修复（脚本行为、退出码、日志输出）
- [ ] 新增文件系统分支 / 兼容性支持
- [ ] 文档
- [ ] 其他

## 影响面

- [ ] 触及 `src\lol-chain-lock.bat` 的写盘路径
- [ ] 改变退出码语义
- [ ] 仅文档 / 注释

## 自测

请填写真实结果，未测的项目写「未测」，不要留空或推测。

| 项目 | 结果 |
| --- | --- |
| 文件系统 | NTFS / exFAT / FAT32 |
| `lol-chain-probe.bat` 退出码 | |
| `lol-chain-lock.bat`（dry-run）退出码 | |
| `lol-chain-lock.bat --apply` 退出码 | |
| `--restore` 后 SHA256 与备份是否一致 | |

## 安全边界自查

- [ ] 目标路径仍限定在 `<root>\TCLS\wegame_launch.tmp`，未放宽白名单
- [ ] 未引入联网、注册表写入、提权或对游戏本体的任何改动
- [ ] 写操作仍需显式 `--apply`，默认行为保持 dry-run
- [ ] 备份仍在写操作之前完成
*（内容由AI生成，仅供参考）*
