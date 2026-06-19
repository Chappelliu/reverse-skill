# emit-navigator-layer.ps1
# 从 field-journal markdown 或 CSV 反馈数据生成 ATT&CK Navigator v4.5 layer JSON。
#
# 用法：
#   形态 1（CSV → layer，紫队 SOC 反馈合成后用）：
#     .\emit-navigator-layer.ps1 -InputCsv fired.csv -SocCsv soc.csv -OutputLayer out.json -EngagementName "purple-2026-06-18"
#
#   形态 2（field-journal grep Txxxx → layer，事后可视化）：
#     .\emit-navigator-layer.ps1 -InputJournal "..\field-journal\2026-*.md" -OutputLayer out.json -EngagementName "historical-Q2"
#
#   形态 3（示例）：
#     .\emit-navigator-layer.ps1 -Sample -OutputLayer sample.json
#
# 输出：符合 ATT&CK Navigator v4.5 schema 的 JSON 文件。

[CmdletBinding(DefaultParameterSetName='Csv')]
param(
    [Parameter(ParameterSetName='Csv')]
    [string]$InputCsv,
    [Parameter(ParameterSetName='Csv')]
    [string]$SocCsv,

    [Parameter(ParameterSetName='Journal')]
    [string]$InputJournal,

    [Parameter(ParameterSetName='Sample')]
    [switch]$Sample,

    [Parameter(Mandatory=$true)]
    [string]$OutputLayer,

    [string]$EngagementName = "engagement-$((Get-Date).ToString('yyyy-MM-dd'))"
)

$ErrorActionPreference = 'Stop'

# 资源定位
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$templatePath = Join-Path $scriptDir '..\templates\engagement-layer.template.json'
if (-not (Test-Path $templatePath)) {
    throw "template not found: $templatePath"
}

$layer = Get-Content -LiteralPath $templatePath -Raw | ConvertFrom-Json
$layer.name = $EngagementName

$techniques = @()

switch ($PSCmdlet.ParameterSetName) {
    'Csv' {
        if (-not $InputCsv) { throw "Csv mode requires -InputCsv" }
        if (-not (Test-Path $InputCsv)) { throw "InputCsv not found: $InputCsv" }
        $fired = Import-Csv -LiteralPath $InputCsv
        $soc = if ($SocCsv -and (Test-Path $SocCsv)) {
            Import-Csv -LiteralPath $SocCsv | Group-Object technique_id -AsHashTable -AsString
        } else { @{} }

        foreach ($row in $fired) {
            $tid = $row.technique_id
            if (-not $tid) { continue }
            $score = 0; $color = '#e53935'; $comment = "fired @ $($row.fired_at) on $($row.host)"
            if ($soc.ContainsKey($tid)) {
                $s = $soc[$tid][0]
                if ($s.detected -in 'Y','y','true','True','1') {
                    $score = 100; $color = '#43a047'; $comment += " | DETECTED by $($s.siem_rule)"
                } else {
                    $score = 50; $color = '#fdd835'; $comment += " | logged only ($($s.siem_rule))"
                }
            }
            $techniques += [pscustomobject]@{
                techniqueID = $tid
                score = $score
                color = $color
                comment = $comment
                enabled = $true
                metadata = @()
            }
        }
    }
    'Journal' {
        if (-not $InputJournal) { throw "Journal mode requires -InputJournal" }
        $files = Get-ChildItem -Path $InputJournal -ErrorAction Stop
        $tidSet = New-Object System.Collections.Generic.HashSet[string]
        $tidComment = @{}
        foreach ($f in $files) {
            $text = Get-Content -LiteralPath $f.FullName -Raw
            $matches = [regex]::Matches($text, 'T\d{4}(\.\d{3})?')
            foreach ($m in $matches) {
                $tid = $m.Value
                # 跳过 TAxxxx (战术) — 我们只画技术
                if ($tid -match '^TA') { continue }
                $null = $tidSet.Add($tid)
                if (-not $tidComment.ContainsKey($tid)) {
                    $tidComment[$tid] = @()
                }
                $tidComment[$tid] += $f.Name
            }
        }
        foreach ($tid in $tidSet) {
            $sources = ($tidComment[$tid] | Select-Object -Unique) -join ', '
            $techniques += [pscustomobject]@{
                techniqueID = $tid
                score = 100
                color = '#43a047'
                comment = "covered in journal: $sources"
                enabled = $true
                metadata = @()
            }
        }
    }
    'Sample' {
        $techniques = @(
            [pscustomobject]@{ techniqueID='T1003.001'; score=100; color='#43a047'; comment='LSASS dump - detected by Defender'; enabled=$true; metadata=@() },
            [pscustomobject]@{ techniqueID='T1059.001'; score=50;  color='#fdd835'; comment='PowerShell - logged but no SIEM rule'; enabled=$true; metadata=@() },
            [pscustomobject]@{ techniqueID='T1110.003'; score=0;   color='#e53935'; comment='Password spray - undetected'; enabled=$true; metadata=@() }
        )
    }
}

if ($techniques.Count -eq 0) {
    Write-Warning "No techniques produced. Output layer will be empty."
}

$layer.techniques = @($techniques)
$layer.description = "$EngagementName - $($techniques.Count) technique(s) covered"

# 输出
$outDir = Split-Path -Parent $OutputLayer
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$json = $layer | ConvertTo-Json -Depth 10
$json | Set-Content -LiteralPath $OutputLayer -Encoding UTF8

Write-Host "[emit-navigator-layer] OK — wrote $($techniques.Count) techniques to $OutputLayer" -ForegroundColor Green
Write-Host "  -> Open at https://mitre-attack.github.io/attack-navigator/ (Open Existing Layer)" -ForegroundColor Cyan
