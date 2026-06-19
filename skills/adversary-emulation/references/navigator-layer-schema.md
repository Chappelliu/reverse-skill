# ATT&CK Navigator Layer Schema / 形态 C · layer 生成 + 渲染

> 上游入口：`SKILL.md` → 形态 C。
> 适用：（1）从 field-journal 历史日志生成热力图；（2）与形态 A/B 联动产出 layer JSON。
> 输出文件：`attack-navigator-layer.json` 符合 ATT&CK Navigator v4.5 schema。

## Schema 最小可用模板

```json
{
  "name": "engagement-name",
  "description": "engagement description; what we ran and where",
  "domain": "enterprise-attack",
  "versions": {
    "attack": "15",
    "navigator": "5.1.0",
    "layer": "4.5"
  },
  "sorting": 0,
  "viewMode": 0,
  "hideDisabled": false,
  "techniques": [
    {
      "techniqueID": "T1003.001",
      "score": 100,
      "color": "#43a047",
      "comment": "fired @ 2026-06-18 14:23, detected by Defender (TTL=2s)",
      "enabled": true,
      "metadata": []
    },
    {
      "techniqueID": "T1059.001",
      "score": 50,
      "color": "#fdd835",
      "comment": "fired but only WMI-Activity 5860 logged; no SIEM rule",
      "enabled": true
    }
  ],
  "gradient": {
    "colors": ["#ff6666", "#ffe766", "#8ec843"],
    "minValue": 0,
    "maxValue": 100
  },
  "legendItems": [
    { "label": "Detected (score=100)", "color": "#43a047" },
    { "label": "Logged but no rule (score=50)", "color": "#fdd835" },
    { "label": "Not detected (score=0)", "color": "#e53935" }
  ],
  "metadata": [
    { "name": "engagement-id", "value": "self-audit-2026-06-17" },
    { "name": "soc-team", "value": "{anonymized}" }
  ]
}
```

## 字段说明

| 字段 | 必需 | 说明 |
|------|:---:|------|
| `name` | ✓ | 在 Navigator UI 上显示 |
| `domain` | ✓ | `enterprise-attack` / `mobile-attack` / `ics-attack` |
| `versions.attack` | ✓ | ATT&CK 数据版本（15 = 2024 年发布） |
| `versions.layer` | ✓ | 4.5 是 v5.x Navigator 的当前 schema |
| `techniques[].techniqueID` | ✓ | Txxxx 或 Txxxx.xxx |
| `techniques[].score` | 推荐 | 0-100，配合 gradient 着色 |
| `techniques[].color` | 可选 | 直接指定颜色，覆盖 gradient |
| `techniques[].comment` | 强推荐 | 鼠标悬停显示；写"何时 fire / 是否检出 / 备注" |
| `gradient` | 推荐 | 颜色映射；红→黄→绿 = 未检→部分→已检 |

---

## 渲染路径

### 路径 A · 在线（最快）

1. 打开 https://mitre-attack.github.io/attack-navigator/
2. 顶部 → "Open Existing Layer" → "Upload from local"
3. 选你的 `attack-navigator-layer.json`
4. 截图导出 / SVG 下载

### 路径 B · 离线（git）

```bash
git clone https://github.com/mitre-attack/attack-navigator.git
cd attack-navigator/nav-app
npm install && npm run build
npx serve -l 4200 dist
# 浏览器 http://localhost:4200 → Open Existing Layer
```

### 路径 C · 自动渲染（diagram-generator hook）

```powershell
# 调 diagram-generator/scripts/render-navigator-layer.ps1
.\skills\diagram-generator\scripts\render-navigator-layer.ps1 `
    -Layer attack-navigator-layer.json `
    -Output engagement-heatmap.png
# 内部调用 attack-navigator-cli 或 puppeteer 截图本地 navigator
```

详见 `diagram-generator/SKILL.md` §Navigator 热图渲染。

---

## emit-navigator-layer.ps1 用法

```powershell
# 形态 1：从 CSV 数据生成（Atomic Red Team 形态 A 输出）
.\skills\adversary-emulation\scripts\emit-navigator-layer.ps1 `
    -InputCsv "out/fired-techniques.csv" `
    -SocCsv   "out/soc-feedback.csv" `
    -OutputLayer "out/layer.json" `
    -EngagementName "purple-team-2026-06-18"

# 形态 2：从 field-journal 自动抽 Txxxx
.\skills\adversary-emulation\scripts\emit-navigator-layer.ps1 `
    -InputJournal "skills/field-journal/2026-05-25_*.md" `
    -OutputLayer "out/historical.json" `
    -EngagementName "historical-coverage-2026-Q2"

# 形态 3：示例（用于熟悉 schema）
.\skills\adversary-emulation\scripts\emit-navigator-layer.ps1 -Sample -OutputLayer out/sample.json
```

CSV 格式期待：
```
fired-techniques.csv:
  technique_id,fired_at,host,exit_code
  T1003.001,2026-06-18T14:23:00Z,WIN-DC01,0

soc-feedback.csv:
  technique_id,detected,siem_rule,severity
  T1003.001,Y,Defender:CredentialDumpingLSASS,High
```

---

## Schema 校验

```powershell
# 用 jsonschema (pip install jsonschema)
$layer = Get-Content out/layer.json -Raw
$schemaUrl = "https://raw.githubusercontent.com/mitre-attack/attack-navigator/master/nav-app/src/assets/layerupgrade.schema.json"
# 用 attack-navigator UI 的报错也是有效的 lint 方法
```

校验失败常见原因：
- `domain` 拼错（必须是 `enterprise-attack`）
- `techniqueID` 含小写字母（必须 `T1003.001` 不是 `t1003.001`）
- `score` 超出 0-100
- `versions.layer` 与实际 Navigator 版本不匹配

---

## 与本仓的联动 

```
P0.1 标注全包 Txxxx ──┐
                       ▼
field-journal 中每条经验 ──┐
                            ▼
emit-navigator-layer.ps1 ──→ layer.json
                            ▼
diagram-generator hook   ──→ heatmap.png/svg
                            ▼
docs-generator 报告 嵌入  ──→ 紫队最终交付物
```

**没有 P0.1 的 Txxxx 标注 → emit 脚本输出空 layer**。所以 P0.1 是本 skill 的硬前置。

---

## 参考

- [ATT&CK Navigator GitHub](https://github.com/mitre-attack/attack-navigator)
- [Layer file format reference](https://github.com/mitre-attack/attack-navigator/blob/master/layers/LAYERFORMATv4_5.md)
- [attack-cti Python lib](https://github.com/hslatman/attack-cti)（layer 生成时查 ATT&CK 元数据）
