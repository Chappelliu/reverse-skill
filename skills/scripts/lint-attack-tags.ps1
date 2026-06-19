# lint-attack-tags.ps1
# Verify ATT&CK technique-ID tagging on tactic-level section headers.
#
# Convention (see CONTRIBUTING.md §0.1):
#   ## <中文> / <English> (TAxxxx)            ← tactic-level (THIS LINTER ENFORCES)
#   ### <中文> / <English> (Txxxx[.xxx])      ← technique-level (advisory, not enforced here)
#
# Scope: ONLY H2 headings. Technique-level (H3) tagging is mechanical and
# rolled out incrementally per CONTRIBUTING.md §0.1; flagging every H3 across
# legacy docs would generate noise that drowns the real tactic-level breaches.
#
# This linter flags H2 headings whose text mentions a known ATT&CK tactic
# name (Chinese OR English) but does NOT carry a (TA|T)xxxx suffix. Headings
# outside this whitelist (generic prose like "工具速查", "参考资料",
# "工作流") are NOT flagged — only tactic-aligned ones are.
#
# Exit 0  = all good
# Exit 1  = found violations (printed to stderr)

[CmdletBinding()]
param(
    [string]$Root,
    [switch]$ShowOk
)

$ErrorActionPreference = 'Stop'

if (-not $Root) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $Root = Join-Path $scriptDir '..'
}
$Root = (Resolve-Path -LiteralPath $Root).Path

# Tactic vocabulary — Chinese alias + English name + canonical TA id.
# Headings matching ANY of these tokens are required to carry a (Txxxx) tag.
$tacticVocab = @(
    @{ Tokens = @('侦察','reconnaissance');                        Tactic = 'TA0043' },
    @{ Tokens = @('资源开发','resource development');              Tactic = 'TA0042' },
    @{ Tokens = @('初始访问','initial access');                    Tactic = 'TA0001' },
    @{ Tokens = @('persistence','持久化','权限维持');              Tactic = 'TA0003' },
    @{ Tokens = @('权限提升','privilege escalation','privesc','提权'); Tactic = 'TA0004' },
    @{ Tokens = @('防御绕过','defense evasion','防御规避','edr/av 绕过','edr 绕过'); Tactic = 'TA0005' },
    @{ Tokens = @('凭证获取','credential access','凭证访问');       Tactic = 'TA0006' },
    @{ Tokens = @('横向移动','lateral movement');                  Tactic = 'TA0008' },
    @{ Tokens = @('采集','collection');                            Tactic = 'TA0009' },
    @{ Tokens = @('外带','exfiltration','exfil');                  Tactic = 'TA0010' },
    @{ Tokens = @('command and control','命令与控制','c2 流量','c2 通信'); Tactic = 'TA0011' },
    @{ Tokens = @('影响','impact');                                Tactic = 'TA0040' },
    @{ Tokens = @('痕迹清理','anti-forensics');                    Tactic = 'T1070' }
)

# False-positive denylist — heading text fragments that look tactic-aligned
# but are actually about non-ATT&CK topics (RE tools, CTF metadata, project
# routing prose). Skip headings containing ANY of these tokens.
$denyTokens = @(
    'symbolic execution',     # angr / Triton / Manticore — RE tooling
    'routing execution',      # routing.md prose
    '执行要求',                # js-reverse 流程要求
    '执行契约',
    'mode switching',          # CTF writeups
    '0ctf','hxp','hack.lu','32c3','bsidessf','def con','ctf', # CTF year tags
    'discovery 探针','oidc discovery','dnsrecon','adcs','vtable','windows鏉冮檺','linux鏉冮檺',
    'reconstruction',          # "GPIO Reconstruction" / "vtable Reconstruction"
    'discover '                # "Discovery Spike" etc.
)

# Markdown files to scan: every .md under skills/ EXCEPT field-journal entries
# (those record actual operations and aren't process documentation).
$mdFiles = Get-ChildItem -Path $Root -Recurse -Filter '*.md' |
    Where-Object { $_.FullName -notmatch '\\field-journal\\' }

$violations = @()
# Allow comma OR slash as separator: (TA0007 / TA0008) or (T1003, T1558).
# Em-/en-dashes were tried but Windows PowerShell regex char-class semantics
# made them brittle across encodings — stick to ASCII separators.
$idRegex = '\(T(A?)\d{4}(\.\d{3})?(\s*[,/]\s*T(A?)\d{4}(\.\d{3})?)*\)'

foreach ($file in $mdFiles) {
    $relPath = $file.FullName.Substring($Root.Length).TrimStart('\','/')
    $lines = Get-Content -LiteralPath $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # H2 ONLY — tactic-level. H3 (technique-level) is incremental per CONTRIBUTING.md §0.1.
        if ($line -notmatch '^##\s+\S') { continue }
        if ($line -match '^###') { continue }

        $headingText = $line -replace '^##\s+',''
        $lowerText = $headingText.ToLowerInvariant()

        # Skip if any deny-token appears in the heading
        $denied = $false
        foreach ($d in $denyTokens) {
            if ($lowerText -like "*$d*") { $denied = $true; break }
        }
        if ($denied) { continue }

        # Does it look like a tactic-aligned heading?
        $matched = $null
        foreach ($v in $tacticVocab) {
            foreach ($tok in $v.Tokens) {
                if ($lowerText -like "*$tok*") {
                    $matched = $v.Tactic
                    break
                }
            }
            if ($matched) { break }
        }
        if (-not $matched) { continue }

        # Has the heading already got a (Txxxx) or (TAxxxx) tag?
        if ($headingText -match $idRegex) {
            if ($ShowOk) {
                Write-Host "OK  $relPath`:$($i+1) → $headingText" -ForegroundColor DarkGray
            }
            continue
        }

        $violations += [pscustomobject]@{
            File    = $relPath
            Line    = $i + 1
            Heading = $headingText.Trim()
            Suggest = "($matched)"
        }
    }
}

if ($violations.Count -eq 0) {
    Write-Host "[lint-attack-tags] OK — all tactic-aligned headings carry an ATT&CK ID." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "[lint-attack-tags] FAIL — $($violations.Count) heading(s) missing ATT&CK ID:" -ForegroundColor Red
foreach ($v in $violations) {
    [Console]::Error.WriteLine(("  {0}:{1}  '{2}'  → suggest: {3}" -f $v.File, $v.Line, $v.Heading, $v.Suggest))
}
Write-Host ""
Write-Host "Convention: append (Txxxx[.xxx]) or (TAxxxx) to tactic-level headings." -ForegroundColor Yellow
Write-Host "See: skills/CONTRIBUTING.md §0.1 ATT&CK 双语标注规范" -ForegroundColor Yellow
exit 1
