# MITRE ATT&CK Coverage Audit — Reverse-Engineering Skill Routing Pack

> Role: Red-team / vulnerability-discovery review of this skill router (the *repository itself*, not an external target).
> Frame: MITRE ATT&CK Enterprise v15 (14 tactics) + Cloud / Mobile / ICS matrices + adversary-emulation tooling.
> Date: 2026-06-17. Verdict scale: ✅ Strong · 🟡 Partial · 🔴 Gap · ⚫ Deliberately out-of-scope.

---

## 0. Executive summary

This pack is **offensively broad and unusually deep on RE + Windows/AD + web pentest**. Against the
ATT&CK *Enterprise on-prem* matrix it is ~80% covered. The real gaps cluster in five places:

1. **Resource Development (TA0042)** — not treated as a phase; omitted from the existing ATT&CK map.
2. **Collection (TA0009)** — only DB/file dumping; 8+ technique families absent.
3. **Exfiltration (TA0010)** — listed in the map but no technique/tooling body anywhere.
4. **Cloud / Identity-Provider attack path** — CTF-sandbox modules exist, but no *enterprise* cloud red-team skill (AWS/Azure/Entra/GCP), so cloud Discovery/PrivEsc/Lateral/Exfil are thin.
5. **Threat-informed structure** — **zero** ATT&CK technique IDs (`Txxxx`) anywhere in the repo, and no Caldera / Atomic Red Team / ATT&CK Navigator layer. Findings can't be expressed or visualized in ATT&CK terms.

Everything below is evidence-backed against files in `skills/` and `../CTF-Sandbox-Orchestrator/`.

---

## 1. Per-tactic coverage matrix (Enterprise)

| # | Tactic | Verdict | Where it lives | Missing steps (technique-level) |
|---|--------|:------:|----------------|---------------------------------|
| TA0043 | Reconnaissance | ✅ | `attack-chain` §1, `network-attack-defense` §侦察 | Active scanning of cloud assets; victim-owned mobile-app store recon. Minor. |
| TA0042 | **Resource Development** | 🔴 | scattered only (phishing infra, C2 domain notes in failure table, supply-chain poisoning) | **No phase coverage:** acquire/compromise infrastructure (redirectors, domain fronting/aging, CDN setup), develop/stage capabilities (payload & malware build, malleable C2 profiles), establish accounts (sock puppets), **code-signing cert acquisition/theft**, drive-by/malvertising staging. Omitted from the ATT&CK map table. |
| TA0001 | Initial Access | ✅ | `attack-chain` §2, `pentest-tools`, `src-hunter` | Drive-by compromise; trusted-relationship/3rd-party SaaS abuse (light). |
| TA0002 | Execution | 🟡 | `network-attack-defense` (WMI/PS/cmd injection) | No consolidated section. Missing: LOLBins catalogue, scheduled-task/cron *execution*, container/serverless exec, ESXi admin, inter-process comm, native API. |
| TA0003 | Persistence | ✅ | `attack-chain` §5, `network-attack-defense`, CTF `competition-browser-persistence` | BITS jobs; cloud-function triggers (light). |
| TA0004 | Privilege Escalation | ✅ | `attack-chain` §3, `network-attack-defense` | Cloud IAM privesc partly (see Cloud row). |
| TA0005 | Defense Evasion | ✅ | `edr-bypass-re`, `attack-chain` §6, `malware-analysis` (94 anti-analysis) | Rootkit/bootkit (have kernel-driver-reverse); cloud log evasion. |
| TA0006 | Credential Access | 🟡 | `attack-chain` §4.1, `network-attack-defense` §凭证, `competition-lsass/dpapi/kerberos` | **Modern gaps:** AiTM cookie theft (Evilginx-class / "steal web session cookie"), **MFA fatigue / push-bombing**, browser & password-store credential dumping (KeePass, browser vaults), application/OAuth **access-token theft**, mitm6/IPv6 poisoning (have Responder LLMNR only). |
| TA0007 | Discovery | 🟡 | `network-attack-defense` §内网, BloodHound | **Cloud/container discovery** (cloud dashboards, IAM enum, kubectl recon — CTF k8s module exists but sandbox-flavored), network-share & software/security discovery not consolidated. |
| TA0008 | Lateral Movement | ✅ | `attack-chain` §4, tunnels (chisel/ligolo) | Internal spearphishing; RDP/SSH session hijack; cloud role-chaining (light). |
| TA0009 | **Collection** | 🔴 | only "DB export, file collection" | **Missing:** screen capture, keylogging, audio/clipboard, **email collection** (CTF `competition-mailbox-abuse` is sandbox-only), data from local/network/cloud storage, browser session data, **archive-collected-data** (rar/7z+pw staging), automated collection, data from info repositories (SharePoint/Confluence/GitLab). |
| TA0011 | Command & Control | ✅ | `attack-chain` §6.3, `network-attack-defense` §C2 | Web-service C2 channels (light vs. exfil overlap). |
| TA0010 | **Exfiltration** | 🔴 | one row in ATT&CK map, **no body** | **No technique/tooling:** exfil over web service (Telegram/GitHub/Mega/pastebin), over alternative protocol (DNS/ICMP — iodine/DNSExfiltrator), scheduled transfer, **size-limit chunking**, exfil over C2 channel, transfer to cloud account, physical-medium exfil. |
| TA0040 | Impact | ⚫ | intentionally excluded ("禁止 DoS / 不影响业务可用性") | For authorized purple-team: ransomware *simulation*, data-encrypted-for-impact, inhibit-system-recovery, defacement, account-access-removal, data manipulation. See §4 — this should be an *explicit guarded* scope decision, not a silent omission. |

### Existing ATT&CK map is incomplete
`pentest-tools/references/network-attack-defense.md` already has a mapping table — but it lists **12 tactics, omits Resource Development**, and its Collection/Exfiltration rows have no corresponding body content. The map should be promoted to 14 tactics and made the canonical index.

---

## 2. Cross-matrix coverage (beyond Enterprise on-prem)

| Matrix | Verdict | Notes |
|--------|:------:|-------|
| **ATT&CK Cloud (IaaS/SaaS/Identity Provider/Office Suite)** | 🔴 | `attack-chain` §2.6/§3.4 give a few AWS/Azure snippets; CTF has `competition-agent-cloud`, `competition-cloud-metadata-path`, `competition-k8s-control-plane`, `competition-container-runtime`, `competition-oauth-oidc-chain` — but these are **CTF/sandbox-shaped**. No enterprise cloud red-team skill with ScoutSuite/Prowler/Pacu/CloudFox/ROADtools/AzureHound/PMapper. Biggest enterprise gap given cloud-first orgs. |
| **ATT&CK Mobile** | 🟡 | `apk-reverse` + `mobile-reverse` are **RE-focused** (MASTG, Frida, SSL-pin/root/jailbreak bypass), not ATT&CK-Mobile tactics (mobile C2, mobile collection/exfil, abuse of accessibility/device admin). Fine if mobile = RE only; gap if mobile = device compromise op. |
| **ATT&CK ICS / OT** | 🔴 | `firmware-pentest` covers IoT firmware extraction/emulation/fuzz (OWASP FSTM) but **no ICS ATT&CK** (Modbus/S7comm/DNP3, PLC stop/program-download, SCADA HMI). Gap only if OT is in scope — flag, don't necessarily build. |
| **Containers matrix** | 🟡 | CTF `competition-container-runtime` + `competition-kernel-container-escape` cover escape; missing image-build backdooring, registry abuse, k8s RBAC privesc as a red-team flow. |

---

## 3. Structural / threat-informed gaps (highest leverage, low effort)

These are *meta*-gaps — they multiply the value of everything already in the pack:

1. **No technique-ID tagging.** `grep -rohE "T1[0-9]{3}"` across `skills/` and the CTF pack returns **0 hits**. Tagging each playbook step with its `Txxxx` ID would let `docs-generator` emit ATT&CK-mapped findings and `diagram-generator` emit **ATT&CK Navigator layers** (heatmaps of what an engagement touched). This is the single highest-ROI fix.
2. **No adversary-emulation bridge.** No MITRE **Caldera**, **Atomic Red Team**, or **VECTR**. The pack does *manual* technique execution but can't run a repeatable, ATT&CK-numbered emulation plan or feed purple-team detection validation.
3. **No coverage-visualization artifact.** Recommend a generated `attack-navigator-layer.json` per engagement (ties Completion Checklist → ATT&CK Navigator).
4. **Detection/validation half is thin.** `network-attack-defense` has good blue-team checklists, but there's no loop that says "executed T1003.001 → did the EDR/SIEM fire?" — i.e., no purple-team feedback. This is what Caldera/Atomic + Sigma (`malware-analysis` has Sigma) would close.

---

## 4. Recommended *additions* (prioritized)

**P0 — close the red gaps + threat-informed layer**
- New skill `cloud-attack/` (AWS/Azure/GCP/Entra red-team): enum→IAM privesc→lateral(role chaining)→persistence→exfil. Tools below.
- New reference `attack-chain/references/collection-exfil.md`: technique-level Collection + Exfiltration with tooling and detection notes.
- Promote `network-attack-defense` ATT&CK map to **14 tactics**, add a `Txxxx` column, make it the canonical index linked from `routing.md`.
- Add `Txxxx` tags to existing playbook headers (mechanical, high ROI).

**P1 — emulation + cloud discovery**
- New skill (or `attack-chain` section) `adversary-emulation/`: Caldera + Atomic Red Team + Navigator-layer output, wired into the Completion Checklist.
- Resource Development reference: infra (redirectors/domain fronting/aging), payload/profile build, code-signing.

**P2 — breadth**
- ICS/OT note in `firmware-pentest` (scope-flag only). ATT&CK-Mobile section in `mobile-reverse` if device-op scope appears.

**Scope decision to make explicit:** Impact (TA0040) is currently silently dropped. Recommend a *guarded* `impact-simulation` note (authorized purple-team only, reversible, no real DoS) rather than omission — and state the boundary in `RULES.md` Security Boundaries.

---

## 5. Suggested MCP tools (mapped to the gaps)

> Already in the pack (don't re-add): `mcp-kali-server`, `MetasploitMCP`, `HexStrike-AI`, `Pentest-Swarm-AI`, `pentestMCP`, `mcp-security-hub`, BurpSuite MCP, IDA MCP, Ghidra MCP, `jshookmcp`, `anything-analyzer`, nmap-mcp, nuclei-mcp.

| Gap / Tactic | Suggested MCP server | What it adds |
|--------------|----------------------|--------------|
| **Recon / Resource Dev / CTI** | **Shodan MCP**, **Censys MCP**, **VirusTotal MCP**, **MISP MCP**, **OpenCTI MCP**, **cve-search / NVD MCP**, **searchsploit/ExploitDB MCP** | Passive recon, infra & malware intel, N-day sourcing — feeds TA0043/TA0042 and `patch-diff-exploit`. |
| **Cloud ATT&CK** | **Prowler MCP** (official), **ScoutSuite**, **Pacu** (AWS exploit), **CloudFox**, **ROADtools / AzureHound**, **PMapper**, **Steampipe MCP**, official **AWS MCP** / **Azure MCP**, **kubectl / k8s MCP** | The entire missing cloud/identity attack path; pairs with proposed `cloud-attack/`. |
| **AD Discovery / Lateral** | **BloodHound MCP** (community), **NetExec via mcp-kali**, **ldapdomaindump MCP** | Graph-driven AD pathing exposed to the agent (you reference BloodHound but only as CLI). |
| **Collection / Forensics** | **Volatility MCP** (memory), **Wireshark/tshark MCP** (e.g. SharkMCP), **mcp-pcap** | Memory/traffic collection + analysis; also serves blue-team/IR and `malware-analysis`. |
| **Adversary Emulation (threat-informed)** | **MITRE Caldera MCP/plugin**, **Atomic Red Team (`invoke-atomicredteam`) MCP**, **mitre-attack / attack-navigator MCP** (query technique data, emit layers) | Turns manual steps into repeatable, `Txxxx`-numbered, Navigator-visualized emulation + purple-team validation. Directly closes §3. |
| **Web AiTM / Credential Access** | **mitmproxy MCP** | AiTM/session-cookie capture, fills the Evilginx-class gap (Evilginx itself has no MCP — drive via kali-server). |
| **Supply chain / SAST** | **Semgrep MCP** (official), **CodeQL MCP**, **Snyk MCP**, **OSV MCP**, **GitHub MCP** | Reachability + secret/dep recon; augments `supply-chain-security` (you have Trivy/Syft/Gitleaks as CLIs, not MCP). |
| **Mobile** | **MobSF MCP** (MobSF REST→MCP), **Frida MCP** | Automated MASTG + dynamic instrumentation as agent tools; augments `apk-reverse`/`mobile-reverse`. |
| **Aggregators (optional)** | **cyproxio/mcp-for-security** (nmap/ffuf/sqlmap/nuclei/masscan/amass… bundled) | Alternative to HexStrike for one-shot tool exposure; reference in `kali-mcp-ecosystem.md`. |

---

## 6. Concrete edit list (if you act on this)

1. `pentest-tools/references/network-attack-defense.md` → 14-tactic map + `Txxxx` column.
2. New `attack-chain/references/collection-exfil.md` (TA0009 + TA0010 bodies).
3. New `skills/cloud-attack/SKILL.md` + routing.md rows (target: Cloud/Identity/SaaS).
4. New `skills/adversary-emulation/SKILL.md` (Caldera/Atomic/Navigator) + Completion-Checklist hook to emit a Navigator layer.
5. `kali-mcp-ecosystem.md` → add the MCP servers in §5 with install lines.
6. `RULES.md` Security Boundaries → explicit Impact-simulation boundary.
7. Mechanical pass: tag playbook headers with technique IDs.

> Net: the pack is a strong *offensive technique library*; the work remaining is making it **threat-informed** (ATT&CK-numbered + Navigator-visualized + emulation-runnable) and filling **Resource Development, Collection, Exfiltration, and enterprise Cloud**.
