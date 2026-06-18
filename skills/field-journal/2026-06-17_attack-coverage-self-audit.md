# 2026-06-17 ATT&CK 覆盖度自审（本包元评审）

## 场景分类
其他（红队视角的元评审 / 项目自审，非外部目标）

## 目标概述
以红队渗透与漏洞挖掘专家视角，将本 skill router 对照 MITRE ATT&CK Enterprise(14 战术) + Cloud/Mobile/ICS 矩阵做覆盖度审计，定位缺失步骤并推荐可补充的 MCP 工具。

## 完整执行链路

1. 读 `RULES.md` / `routing.md` / `tool-index.md` 建立基线。
2. 读 `attack-chain/SKILL.md`（7 阶段攻击链最全）、`pentest-tools/SKILL.md`、`network-attack-defense.md`。
3. 校验 `../CTF-Sandbox-Orchestrator/` 实际存在（40+ competition-* 模块，含云/容器/AD/取证）。
4. 三处 grep 验证：技术 ID 标注、对抗模拟框架、云红队/采集外带工具。
5. 产出 `docs/attack-coverage-audit.md` 正式报告。

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| bash `cd skills` 第二次失败 | 工具 shell 状态不跨调用持久化 | 用绝对/相对全路径，不依赖 cwd | 低 |
| 误以为云覆盖缺失 | routing 指向 `../CTF-Sandbox-Orchestrator/` | 实际存在，但为 CTF/sandbox 形态，非企业云红队 | 低 |

## 关键发现（证据）

- `grep -rohE "T1[0-9]{3}" skills/ ../CTF.../` → **0 命中**：全仓库无 ATT&CK 技术 ID 标注。
- 无 Caldera / Atomic Red Team / ATT&CK Navigator / purple-team。
- 无云红队工具（ScoutSuite/Prowler/Pacu/CloudFox/ROADtools/AzureHound/PMapper）。
- 无采集/外带工具（DNSExfiltrator/iodine/keylog 等）。
- 现有 `network-attack-defense.md` 的 ATT&CK 映射只列 12 战术，漏 Resource Development，且 Collection/Exfiltration 行无正文。

## 红队视角结论（缺失步骤）

- 🔴 Resource Development（TA0042）：无独立阶段。
- 🔴 Collection（TA0009）：仅 DB/文件，缺截屏/键盘/邮件/归档/云存储等 8+ 族。
- 🔴 Exfiltration（TA0010）：仅映射表一行，无技术正文。
- 🔴 企业云/身份提供方攻击路径（CTF 形态存在，企业红队缺）。
- 🟡 Credential Access 现代项缺失：AiTM cookie 窃取 / MFA 疲劳轰炸 / 浏览器&密码库凭据 / OAuth token 窃取 / mitm6。
- ⚫ Impact（TA0040）：刻意排除（禁 DoS），建议改为"显式的受控紫队模拟边界"而非静默省略。

## 对本包的改进建议
见报告 §6 编辑清单：14 战术映射 + Txxxx 列；新增 `cloud-attack/`、`adversary-emulation/`、`collection-exfil.md`；`kali-mcp-ecosystem.md` 增补 MCP（Prowler/Pacu/CloudFox/ROADtools、Caldera/Atomic、Volatility/tshark、Semgrep/CodeQL、MobSF/Frida、Shodan/VT/MISP/cve-search）。最高 ROI：技术 ID 标注 + Navigator 层输出。

## 进化动作
- [ ] 更新了路由矩阵（建议项，待用户确认是否建子 skill）
- [ ] 更新了 tool-index
- [ ] 更新了 bootstrap-manifest
- [ ] 更新了子 skill 文档
- [x] 新增了 pitfalls 记录（本条 + 报告）
- [x] 产出正式报告 `docs/attack-coverage-audit.md`

## 环境信息
- OS: Windows 11 / PowerShell 5.1
- 目标平台: 本仓库 `D:\reverse-skill`（skills/ + ../CTF-Sandbox-Orchestrator/）

## 脱敏要求
本条目无真实外部目标、无凭据/IP/域名，无需脱敏。
