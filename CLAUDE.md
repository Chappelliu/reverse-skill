# Reverse-Engineering Skill Routing Pack — Project Instructions

This repository is an AI-agent **security/reverse-engineering skill router**. When working
in this repo, route security/RE tasks through the skill pack before touching tools.

> Package root: this directory (the folder containing `RULES.md`). Do not assume a drive letter.
> Scope: these instructions apply **only inside this project** (project-scoped, no global config).

## When to route

If the user's request matches any of these (English / 中文), run the routing flow **before** acting:

- APK / Android / 反编译 / smali / jadx / apktool / Frida / Hook
- binary / 二进制 / IDA / radare2 / r2 / disassembly / 反汇编 / reverse engineering / 逆向
- frontend signature / 前端签名 / encrypted params / JS reverse / JS 逆向 / jshookmcp / CDP / SourceMap
- packet capture / 抓包 / HTTP capture / request replay / anything-analyzer
- CTF / Pwn / web pentest / Web 渗透 / exploit / 漏洞利用 / privilege escalation / 提权
- penetration testing / 渗透测试 / red team / 红队 / Nmap / Nuclei / SQLMap / FFUF / Hashcat / Metasploit
- firmware / IoT / binwalk / EMBA / EDR bypass / 免杀 / N-day / patch diff / CVE
- LLM security / Prompt injection / jailbreak / Agent security
- symbol migration / 符号迁移 / bindiff / diagram / 流程图 / report / writeup

## Routing flow (read in order, do not preload everything)

1. `RULES.md` — single source of truth for the behavior chain and execution principles
2. `skills/routing.md` — routing matrix (target type / intent / toolchain) → entry sub-skill
3. `skills/field-journal/_index.md` — check for reusable prior experience first
4. `skills/tool-index.md` — local tool availability + **exact installed paths** (machine-generated; gitignored)

## Tool & path rules

- **Never guess tool paths** — read `skills/tool-index.md`; it has the absolute path per tool.
- Missing tool that the task needs → `skills\scripts\bootstrap-reverse.ps1`, then re-run
  `skills\scripts\refresh-tool-index.ps1` to persist new paths.
- `tool-index.md` reflects *this machine's* last scan only. Re-run refresh after installing anything.
- IDA MCP: don't hard-code port 13337 — scan 13337–13350 for the active instance.

## After a task completes

Run the completion checklist from `RULES.md`: generate report (`docs-generator`),
write back to `skills/field-journal/` (anonymized) and update `_index.md`.

## Environment notes (this machine)

- OS: Windows; shell: Windows PowerShell 5.1 (no `pwsh`). PowerShell scripts in this repo
  must be saved as **UTF-8 with BOM** or PS 5.1 mis-parses their Chinese text under a CJK locale.
- Detected toolchain at setup: `python` 3.12.8 and `pip` present; everything else auto-installable on demand.
