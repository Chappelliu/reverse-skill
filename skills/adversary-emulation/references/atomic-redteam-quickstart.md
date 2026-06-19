# Atomic Red Team Quickstart / 形态 A · 单技术 fire

> 上游入口：`SKILL.md` → 形态 A。
> 适用：单技术快速验证（"防御方能不能检出 T1003.001"），不做长期编排。

## 必备组件

```text
□ Invoke-AtomicRedTeam   — PowerShell 模块（核心执行引擎）
□ atomic-red-team        — 测试用例库（git 子模块）
```

bootstrap：

```powershell
# 一行装齐（PS Gallery）
IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
Install-AtomicRedTeam -getAtomics

# 验证
Import-Module Invoke-AtomicRedTeam
Invoke-AtomicTest All -ListTests
```

---

## 工作流

```
1. 选定一个 Txxxx —— 例如 T1003.001 (LSASS Memory Dumping)
2. 列出该技术下的 atomic tests:
     Invoke-AtomicTest T1003.001 -ShowDetailsBrief
3. 检查命令（**必看**，避免破坏性操作）：
     Invoke-AtomicTest T1003.001 -TestNumbers 1 -ShowDetails
4. fire:
     Invoke-AtomicTest T1003.001 -TestNumbers 1
5. 等 EDR/SIEM 反馈：
   - 本机看 Defender / 第三方 EDR 的告警
   - SIEM 看 Sysmon / Windows Event Log
6. 清理（如果留下文件/进程）：
     Invoke-AtomicTest T1003.001 -TestNumbers 1 -Cleanup
7. 记录到 fired-techniques.csv：
     technique_id,fired_at,host,exit_code
     T1003.001,2026-06-18T14:23:00Z,WIN-LAB01,0
8. 收 SOC 反馈到 soc-feedback.csv:
     technique_id,detected,siem_rule,severity
     T1003.001,Y,Defender:CredentialDumpingLSASS,High
9. 调 emit-navigator-layer.ps1 → layer.json → diagram-generator → heatmap
10. field-journal 回写
```

---

## 单技术 fire 模板

```powershell
# 单技术全跑
$T = "T1003.001"
Get-AtomicTechnique -Path "$env:PUBLIC\AtomicRedTeam\atomics\$T\$T.yaml"

# 单测试号 fire（推荐分号查 ShowDetails 再跑）
Invoke-AtomicTest $T -TestNumbers 1 -ShowDetails
Invoke-AtomicTest $T -TestNumbers 1 -CheckPrereqs
Invoke-AtomicTest $T -TestNumbers 1 -GetPrereqs
Invoke-AtomicTest $T -TestNumbers 1
# Cleanup（**MUST**，否则留着痕迹）
Invoke-AtomicTest $T -TestNumbers 1 -Cleanup
```

---

## 一组技术 fire（自定义链）

```powershell
# 每条 fire 后自动等 5 秒，给 EDR 反应时间
@(
    'T1059.001-1',     # PowerShell - download cradle
    'T1003.001-1',     # LSASS - procdump
    'T1110.001-1',     # Brute Force - password spray
    'T1547.001-1'      # Persistence - Registry Run Key
) | ForEach-Object {
    $tech, $num = $_ -split '-'
    Write-Host "[+] Firing $tech test #$num" -ForegroundColor Yellow
    Invoke-AtomicTest $tech -TestNumbers $num -CheckPrereqs
    Invoke-AtomicTest $tech -TestNumbers $num
    Start-Sleep -Seconds 5
    Invoke-AtomicTest $tech -TestNumbers $num -Cleanup
}
```

---

## OPSEC / 安全提示

```text
□ Atomic 测试中部分会真的 dump LSASS / 写注册表 / 起反弹 shell
  → ALWAYS 先 -ShowDetails 看清命令再跑
□ SOC 必须事前知情；否则你触发的告警会被当真实事件升级
□ 测试机环境推荐用 vagrant / vm 快照可回滚
□ 在生产环境严禁未经 cleanup 验证就 fire
□ Atomic 是"明牌"工具，跟 Caldera/红队不可混用：跑完不要试图清干净，留痕本身就是数据
```

---

## 与 Caldera 的协作

```
Atomic 用于"快速判断 EDR 是否能检出单点"
  ▼
通过验证的 Txxxx 串成 Caldera adversary profile
  ▼
Caldera 用于"完整链路是否仍可被检出（行为关联）"
```

详见 `caldera-purple-team.md`。

---

## 参考

- [Invoke-AtomicRedTeam](https://github.com/redcanaryco/invoke-atomicredteam)
- [atomic-red-team test library](https://github.com/redcanaryco/atomic-red-team)
- [Wiki: Getting Started](https://github.com/redcanaryco/invoke-atomicredteam/wiki/Getting-Started)
