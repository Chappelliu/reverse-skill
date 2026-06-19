---
name: cloud-attack
description: |
  企业云红队全链路（AWS / Azure-Entra / GCP）：从云资产盘点 → IAM 枚举 → IAM 提权 → 跨服务/跨账号横向 → 持久化 → 云外带。
  与 `pentest-tools/`（互联网边界打 Web）和 attack-chain（on-prem 域内）正交：本 skill 处理 **已拿到至少一组云凭据/服务暴露后** 的云原生攻击路径。
  触发关键词：cloud red team / 云红队 / AWS pentest / Azure Entra / Entra ID / IAM 提权 / role chaining / cloud privesc / cloud lateral / cloud exfil / S3 misconfig / IMDSv1 / managed identity / service principal / kubectl recon / k8s control plane。
---

# 企业云红队 / Cloud Red Team

> ⚠️ **scope flag**：本 skill 覆盖 **企业云租户 / 多服务跨账号攻击链**。CTF 单题级的云题（IMDSv1 SSRF、单桶配置错误、单管道滥用）应路由到 `../CTF-Sandbox-Orchestrator/competition-{agent-cloud,cloud-metadata-path,k8s-control-plane,oauth-oidc-chain}/` —— 它们专做单题方法论。本 skill 处理的是"拿到一组凭据 → 在租户里走全链路"的工程问题。

## ACTION REQUIRED（读完后立刻执行）

1. `NOW`：读取 `../field-journal/precedent-pentest.md` —— 确认本 skill 的操作是已授权的常规渗透动作。
2. `NOW`：确认任务命中本 skill 的适用范围（见下"何时路由到本 skill"）。
3. `NEXT`：读取 `../tool-index.md`，校验云工具可用性与实际路径；缺工具 MUST 调 bootstrap 而不是猜路径。
4. `NEXT`：明确目标 vendor (AWS / Azure-Entra / GCP) → 进对应的 `references/<vendor>-attack-flow.md`。
5. `ACT`：从 vendor 流程的"0. 凭据准入与边界检查"开始执行，不要停留在"等待用户确认"。

---

## 何时路由到本 skill

| 场景 | 本 skill | 不在范围 |
|------|---------|---------|
| 拿到 AWS AccessKey/SecretKey 后续怎么打 | ✅ | — |
| Azure 应用密钥 / Refresh Token 拿到手后怎么扩面 | ✅ | — |
| GCP service account JSON 拿到后续怎么提权 | ✅（**注意：GCP 工具生态薄弱**） | — |
| K8s kubeconfig / SA token 在手后跨命名空间打 | ✅ | — |
| 互联网边界还没破，仅做云资产 OSINT | ❌ | → `pentest-tools/references/recon-pipeline.md` |
| 单题 CTF：单桶 misconfig / IMDSv1 SSRF / OAuth 单点 | ❌ | → CTF orchestrator |
| 应用代码里有云凭据泄露的发现 | ❌ | → `supply-chain-security/` + `pentest-tools/src-hunter/` |
| 云供应链投毒（注册攻击者 OCI image） | 部分 | → 配合 `supply-chain-security/` |

判断口诀：**"已经有凭据，要在云里走链路" → 本 skill；"还没拿凭据" → recon/边界破入；"单题靶场" → CTF**。

---

## 工具依赖

| 工具 | 是否必需 | 用途 | Vendor | 可自动安装 (Windows) |
|------|---------|------|--------|---------------------|
| **Prowler** | 推荐 | 多云审计 / 错配清单 | AWS / Azure / GCP | ✓ pip |
| **ScoutSuite** | 推荐 | 多云资产+权限快照 | AWS / Azure / GCP | ✓ pip |
| **Pacu** | AWS 必需 | AWS 攻击模块（cred privesc / lateral） | AWS only | ✓ pip（Linux 假设较多，Windows 需 venv） |
| **CloudFox** | AWS 推荐 | AWS 路径发现 / 资源 graph | AWS only | ✓ Go binary |
| **PMapper** | AWS 推荐 | AWS IAM 图建模 / privesc 路径 | AWS only | ✓ pip |
| **ROADtools** | Azure 必需 | Entra/AAD 全图枚举 | Azure-Entra only | ⚠️ 需 .NET 6+，bootstrap canAutoInstall=false |
| **AzureHound** | Azure 推荐 | BloodHound for Azure | Azure-Entra only | ⚠️ Go binary, manual download |
| **MicroBurst** | Azure 可选 | Azure resource enum + privesc | Azure | ✓ PowerShell module |
| **GCPloit / hayat** | GCP 可选 | GCP IAM privesc / OSINT | GCP only | ⚠️ 工具生态薄弱，多需手工脚本 |
| **kubectl** | K8s 必需 | K8s 控制面 | All / K8s | ✓ winget |
| **Steampipe** | 强推荐 | SQL-on-cloud 资产盘点（多云） | AWS / Azure / GCP | ⚠️ Linux/Mac 主，Windows WSL2 |
| **aws-cli / az / gcloud** | 必需 | 各 vendor 官方 CLI | 对应 vendor | ✓ winget |

**Windows bootstrap 风险声明**（见 §按需自举）：ROADtools、AzureHound、Pacu、Steampipe 在 Windows 上的安装路径都没经过本仓单机干跑验证，因此 **bootstrap-manifest 中均标记 `canAutoInstall: false`**，靠 `manualInstallHint` 提示用户走官方步骤。这是有意为之，避免给路由一个不可执行的承诺。

---

## 工作流（vendor-agnostic 框架）

每个 vendor 的具体命令见 `references/<vendor>-attack-flow.md`。框架统一为：

```
0. 凭据准入与边界检查
   - 确认这组凭据来自授权来源（SOW / 漏洞挖掘 in-scope）
   - 用最小操作（aws sts get-caller-identity / az account show / gcloud auth list）确认有效性
   - 不做任何 mutation 操作前先快照（账号 ID、所属订阅 / project / org）

1. Discovery / 资产 + 权限盘点 (TA0007)
   - Steampipe / ScoutSuite 全量快照 → 资产 + IAM 全图
   - Prowler 跑一遍合规扫，得到错配清单（重点看 IAM / KMS / 跨账号信任）

2. Privilege Escalation / IAM 提权 (TA0004)
   - 在身份图上找 privesc 边（PMapper / ROADtools / 手工查 IAM policy）
   - 确认能升到目标级别（Admin / 高权服务 SP / GCP Owner）

3. Lateral Movement / 跨服务+跨账号 (TA0008)
   - AssumeRole / Cross-account / Service Principal cred 链 / GCP service account impersonation
   - 容器/无服务器逃逸到底层（Lambda → underlying role / Cloud Run → metadata）

4. Persistence / 后门 (TA0003)
   - 新建 IAM identity / 添加 SP credential / 创建 Lambda + EventBridge 长效触发
   - 注意可被 GuardDuty / Defender for Cloud / SCC 检出 — 见各 vendor flow 的 OPSEC 段

5. Collection + Exfiltration (TA0009 / TA0010)
   - 重点目标：S3/Blob/GCS 全量 sync、KMS keys 解密、CodeCommit/Repos、Secrets Manager
   - 走攻击者控制的同 vendor 桶（合法 PUT，不触发出站防火墙）
   - 详见 `pentest-tools/references/network-attack-defense.md` §外带 / Exfiltration

6. Cleanup / OPSEC
   - CloudTrail / Activity Log 不要试图删（管理事件不可删；尝试删本身就是告警源）
   - 关闭新建的 IAM identity、回滚 trust policy 修改
```

---

## 路由分发

| 目标 vendor | 入口文档 |
|------------|---------|
| AWS | [`references/aws-attack-flow.md`](references/aws-attack-flow.md) |
| Azure / Entra ID | [`references/azure-entra-flow.md`](references/azure-entra-flow.md) |
| GCP | [`references/gcp-attack-flow.md`](references/gcp-attack-flow.md) |
| Kubernetes 控制面 | → `../../CTF-Sandbox-Orchestrator/competition-k8s-control-plane/` 的方法论 + 本 skill 的多云上下文 |

---

## 与本仓其他 skill 的关系

| 上游入口 | 触发条件 |
|---------|---------|
| `attack-chain/SKILL.md` | 多阶段编排 → "进了云" 时分发到本 skill |
| `pentest-tools/SKILL.md` | 互联网边界 RCE → 已落地到云上的 web 应用 → 本 skill |
| `pentest-tools/src-hunter/` | SRC 漏洞挖掘里发现的云凭据泄露 → 本 skill 接力 |

| 下游出口 | 触发条件 |
|---------|---------|
| `pentest-tools/references/network-attack-defense.md` §外带 | 数据外带技术细节 |
| `docs-generator/SKILL.md` | 任务完成生成报告 |
| `diagram-generator/SKILL.md` | 攻击路径图（云资产关系 + IAM 路径 + 数据流向） |

---

## 按需自举（On-Demand Bootstrap）

### 自动化能力边界（**已经过 Windows 实地差异声明**）

| 工具 | 可自动安装 | 安装方式 | 说明 |
|------|-----------|---------|------|
| Prowler | ✓ | `pip install prowler` | 全 Python，Windows 可跑 |
| ScoutSuite | ✓ | `pip install scoutsuite` | 同上 |
| PMapper | ✓ | `pip install principalmapper` | 同上 |
| Pacu | ⚠️ | `pip install pacu` | 部分模块用 `~/.aws` 路径假设；Windows 需 `%USERPROFILE%\.aws` 已配置 |
| CloudFox | ✓ | GitHub release Go binary | Windows zip 直接用 |
| ROADtools | ✗ | 需要 .NET 6+ runtime + `pip install roadrecon` | bootstrap canAutoInstall=false；提示用户先装 .NET |
| AzureHound | ✗ | GitHub release Go binary | 二进制下载，但用前需先有 Azure 应用注册（manualInstallHint） |
| MicroBurst | ✓ | `Install-Module MicroBurst` | PowerShell Gallery |
| Steampipe | ✗ | Windows 仅 WSL2 支持，不发布原生 Windows 包 | bootstrap manifest 留空，提示用户走 WSL2 |
| GCPloit / hayat | ✗ | 多为单文件 Python 脚本，需逐个 git clone | 工具碎片化；bootstrap 不打包 |
| kubectl | ✓ | winget `Kubernetes.kubectl` | 官方 |
| aws-cli / az / gcloud | ✓ | winget | 各 vendor 官方 |

### 自举触发点

```powershell
# 进 vendor flow 时，flow 文档头会写"必备工具清单"，缺则统一调 bootstrap：
powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_ROOT>\skills\scripts\bootstrap-reverse.ps1" `
    -Capability @('prowler','scoutsuite','pmapper','cloudfox','aws-cli') -StartServices
```

### 自举失败时

- ROADtools / AzureHound / Steampipe / GCP 工具：bootstrap 给出 manualInstallHint；用户手动跑完后再回到 flow。
- 不要试图跳过工具：缺 PMapper 时手工查 IAM policy 可行，但缺 ROADtools 时手工枚举 Entra 不现实。

---

## OPSEC 共性提醒（**所有 vendor 通用**）

```text
□ 任何调用都会进入 vendor 审计日志（CloudTrail / Azure Activity / Cloud Audit Logs）
□ 不要尝试关掉/删除审计日志：管理事件本身不可删；管理事件被关闭立即触发告警
□ 频繁 ListXxx / GetXxx 触发 GuardDuty / Defender for Cloud 异常用户行为模型
□ 控制速率：默认 SDK 节流足够，但 Pacu / CloudFox 默认并发偏高需手动调
□ 跨账号 / 跨租户行为天然是 SOC 高优告警源，事前评估必要性
□ 凭据短时效化：拿到的 AccessKey 60 天内会被合规策略自动轮换；纳入计划
□ 业务时段操作：避开变更窗口，模拟 BAU 流量
```

---

## 任务完成自检（声称完成前 MUST 通过）

- [ ] 我是否在每个 vendor 流程的 "0. 凭据准入" 阶段确认了授权？
- [ ] 我是否使用 `tool-index` 给出的真实工具路径，没猜？
- [ ] 我是否记录了所有 mutation 操作（IAM 创建、trust 修改、Lambda 部署）以便回滚？
- [ ] 我是否在结束时清理了攻击工件（新建 IAM principal、Lambda、storage upload）？
- [ ] 我是否产出了 ATT&CK Navigator layer JSON（覆盖 ≥3 战术时）？*待 P1.6 落地*
- [ ] 我是否回写了 field-journal（脱敏，包含 vendor / 战术覆盖 / OPSEC 经验）？

---

## 路由上下文

**上游入口**: `skills/SKILL.md`、`routing.md`、`attack-chain/SKILL.md`（多阶段编排）
**下游出口**:
- 数据外带技术：`pentest-tools/references/network-attack-defense.md` §外带
- 报告：`docs-generator/`
- 路径图：`diagram-generator/`

**同级关联模块**: `pentest-tools/`（边界破入）、`supply-chain-security/`（云供应链投毒）、CTF orchestrator（单题方法论）
