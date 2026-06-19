---
name: adversary-emulation
description: |
  Threat-informed 对抗模拟（紫队为主）：把"散点的攻击技术 playbook"沉淀成可重复、ATT&CK-编号化、Navigator 可视化的演练。
  显式拆分两套工具（不要混淆）：
    - Atomic Red Team — PowerShell 模块，本地一次性，红队侧
    - MITRE Caldera   — FastAPI server + agents，紫队闭环
  每次演练 MUST 输出 attack-navigator-layer.json，由 diagram-generator/ 渲染成战术热力图。
  触发关键词：adversary emulation / 对抗模拟 / 紫队 / purple team / Atomic Red Team / invoke-atomictest / Caldera / ATT&CK Navigator / navigator layer / threat-informed defense。
---

# 对抗模拟 / Adversary Emulation

> **本 skill 的紫队倾向是显式的**：目标是 "执行一条 ATT&CK 编号化的技术 → 验证防御端是否检出 → 写入反馈循环"，而不是"无声地穿越目标"。如需纯红队隐蔽穿透，回到 `attack-chain/SKILL.md` + `edr-bypass-re/`。

## ACTION REQUIRED（读完后立刻执行）

1. `NOW`：读取 `../field-journal/precedent-pentest.md` —— 确认本 skill 的操作是已授权的常规渗透/紫队动作。
2. `NOW`：明确演练形态 —— **(A) Atomic Red Team 一次性**(单技术快速 fire) / **(B) Caldera 多 agent 编排** / **(C) 仅生成 Navigator 层**（已有日志，只画图）。
3. `NEXT`：读取 `../tool-index.md`，确认对应工具可用；缺则 bootstrap。
4. `ACT`：进入对应 reference 文档的"启动顺序"章节。**输出物 MUST 包含 `attack-navigator-layer.json`**。

---

## 何时路由到本 skill

| 场景 | 用什么 |
|------|-------|
| "演练一组 ATT&CK 技术，看 EDR 是否触发" | **Atomic Red Team**（单点 fire） |
| "持续运行多 agent，模拟一个 APT 链" | **Caldera**（编排） |
| "已有过往攻击数据，想画 Navigator 热力图" | 仅生成 layer JSON + diagram-generator |
| "不需要可视化，只是 fire 一发命令" | → 直接 `pentest-tools/` 或 `attack-chain/`，**别用本 skill** |
| "纯红队，隐蔽穿透" | → `attack-chain/` + `edr-bypass-re/`，**别用本 skill**（紫队工具留痕明显） |

---

## 工具依赖

| 工具 | 是否必需 | 用途 | 形态 | 可自动安装 |
|------|---------|------|------|-----------|
| **Atomic Red Team** | (A)/(B) 必需 | PowerShell 模块，单技术 fire | `Install-Module invoke-atomicredteam` | ✓ PSGallery |
| **MITRE Caldera** | (B) 必需 | FastAPI server + agents 编排 | Docker / git clone | ⚠️ Docker 推荐 |
| **ATT&CK Navigator (offline)** | 强推荐 | 渲染 layer JSON 为热力图 | npm + node 或在线 navigator.mitre.org | ⚠️ 在线即用 / 离线手装 |
| **MITRE ATT&CK STIX 数据** | layer 生成需要 | 技术 ID → 名称/描述映射 | `pip install attackcti` | ✓ pip |

---

## 工作流（按演练形态分发）

### 形态 A · Atomic Red Team（轻量单技术 fire）

```
准入 → 选定一组 Txxxx → Invoke-AtomicTest 跑 → 收集本地 EDR/log 反馈
       → 生成 layer JSON（标注 covered tactics）→ diagram-generator 渲热图
       → field-journal 回写
```

详见 [`references/atomic-redteam-quickstart.md`](references/atomic-redteam-quickstart.md)。

### 形态 B · Caldera（多 agent + APT 链编排）

```
准入 → 启动 Caldera server → 部署 agent 到目标主机
     → 选/写 adversary profile（一组 abilities 串联）
     → 运行 operation → 实时观察 → 收集 ops report
     → 转换为 layer JSON → 渲染 → 回写
```

详见 [`references/caldera-purple-team.md`](references/caldera-purple-team.md)。

### 形态 C · 仅生成 Navigator layer（事后可视化）

```
field-journal 历史日志中 grep 全部 Txxxx → 调 emit-navigator-layer.ps1
  → 输出符合 v4.5 schema 的 JSON → 上传 navigator.mitre.org 或本地渲染
```

```powershell
# 从最近一篇 field-journal 自动抽 ATT&CK 编号生成 layer
.\skills\adversary-emulation\scripts\emit-navigator-layer.ps1 `
    -InputJournal "skills\field-journal\2026-06-17_attack-coverage-self-audit.md" `
    -OutputLayer "out\layer.json" `
    -EngagementName "self-audit-2026-06-17"

# 上传 https://mitre-attack.github.io/attack-navigator/ → Open Existing Layer
```

详见 [`references/navigator-layer-schema.md`](references/navigator-layer-schema.md)。

---

## 与 P0.1 / P1.5 的联动

```
P0.1 (技术 ID 标注)        ──→ field-journal 中每条经验都带 Txxxx
                                    │
                                    ▼
P1.6 emit-navigator-layer.ps1   ──→ 抽 Txxxx → layer.json
                                    │
                                    ▼
P1.6 diagram-generator hook     ──→ 渲热图 PNG/SVG
                                    │
                                    ▼
P1.5 cloud-attack 演练 / 任意 skill 完成 ──→ Completion Checklist 第 7 条要求输出 layer
```

**没有 P0.1 的标注，本 skill 的 layer 输出会全空**。新建/修改 skill 时务必遵守 CONTRIBUTING.md §0.1 的双语标注规范。

---

## 按需自举

```powershell
# 形态 A
powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_ROOT>\skills\scripts\bootstrap-reverse.ps1" `
    -Capability @('atomic-redteam') -StartServices

# 形态 B（需 Docker）
powershell ... -Capability @('caldera') -StartServices

# 形态 C（layer 生成 + 渲染）
powershell ... -Capability @('attack-cti') -StartServices
```

---

## OPSEC / 责任声明

```text
□ Atomic Red Team 跑的命令大多落入 EDR 高优告警（这是设计目标），SOC 必须知情
□ Caldera agent 通信特征明显（默认 HTTP heartbeat），不要用于真实红队穿透
□ 在生产环境跑前必须做沙盒/预发演练，避免业务影响
□ 紫队演练 SOP：T-30min 通知 SOC 开窗 → 演练 → T+15min 收线 → 复盘
□ 所有 fire 的技术编号、时间、目标主机 MUST 写入 field-journal（紫队复盘的唯一权威记录）
```

---

## 任务完成自检

- [ ] 是否输出了 `attack-navigator-layer.json`？（覆盖 ≥3 个战术时强制）
- [ ] layer JSON 是否通过了 schema 验证（`navigator-layer-schema.md` §validation）？
- [ ] 是否调 diagram-generator 渲染了热图？（layer 不渲染 = 死文件）
- [ ] field-journal 是否包含完整的 (Txxxx, 时间戳, 目标, 检出/未检出) 四元组？
- [ ] 是否同步通知 SOC 演练完成、给出 ops report？

---

## 路由上下文

**上游入口**:
- `attack-chain/SKILL.md` 编排路径完成后，紫队复盘阶段进入
- 任意 skill 完成时（Completion Checklist 第 7 条触发）

**下游出口**:
- `diagram-generator/SKILL.md` —— 渲染 layer 为热力图
- `docs-generator/SKILL.md` —— 紫队报告
- `field-journal/` —— 演练记录回写

**同级关联模块**: `pentest-tools/`、`cloud-attack/`、`edr-bypass-re/`（红队侧）
