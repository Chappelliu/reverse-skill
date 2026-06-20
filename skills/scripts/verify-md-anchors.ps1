# verify-md-anchors.ps1
# Validate every `path/to/file.md#anchor` link inside skills/*.md against the
# actual heading slugs GitHub would generate (github-slugger algorithm).
#
# GitHub's anchor algorithm (github-slugger, as used on github.com):
#   slug = text
#     .toLowerCase()
#     .replace(/<[^>]+>/g, '')                 # strip inline HTML
#     .replace(/[^\w-￿\s-]/g, '')    # drop punctuation; KEEP \w, CJK
#                                                #   (-￿), spaces, hyphens
#     .trim()
#     .replace(/\s+/g, '-')                     # collapse spaces -> single hyphen
#   Duplicate slugs get -1, -2 suffixes; we don't model that (rare for our docs).
#
# Exit 0 = all links resolve; Exit 1 = broken links printed to stderr.

[CmdletBinding()]
param(
    [string]$Root
)

$ErrorActionPreference = 'Stop'
if (-not $Root) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $Root = Join-Path $scriptDir '..'
}
$Root = (Resolve-Path -LiteralPath $Root).Path

function Get-GfmSlug {
    param([string]$Heading)
    $s = $Heading.ToLowerInvariant()
    $s = [regex]::Replace($s, '<[^>]+>', '')
    # github-slugger keeps letters + numbers of ANY script (\p{L}\p{N}),
    # plus whitespace and hyphens. Strips ALL punctuation — ASCII (& . / ( ))
    # AND full-width (（）·) — which is what github.com actually does.
    # (The earlier [^\w￿\s-] range wrongly KEPT full-width parens because
    # they fall in U+200B-U+FFFF, producing false-positive mismatches.)
    $s = [regex]::Replace($s, '[^\p{L}\p{N}\s\-]', '')
    $s = $s.Trim()
    $s = [regex]::Replace($s, '\s+', '-')
    return $s
}

# Build a map: file -> set of valid slugs (from all H1-H6 headings)
$slugIndex = @{}
$mdFiles = Get-ChildItem -Path $Root -Recurse -Filter '*.md' -ErrorAction SilentlyContinue
foreach ($f in $mdFiles) {
    $rel = $f.FullName.Substring($Root.Length).TrimStart('\','/') -replace '\\','/'
    $slugs = New-Object System.Collections.Generic.HashSet[string]
    $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        if ($line -match '^(#{1,6})\s+(.+?)\s*$') {
            $heading = $matches[2]
            $slug = Get-GfmSlug $heading
            if ($slug) { $null = $slugs.Add($slug) }
        }
    }
    $slugIndex[$rel] = $slugs
}

# Scan every .md for markdown links of form ](relative.md#anchor) or ](path/file.md#anchor)
$linkRegex = '\]\(([^)]+\.md)(#[^)]*)?\)'
$violations = @()
$checked = 0

foreach ($f in $mdFiles) {
    $relSrc = $f.FullName.Substring($Root.Length).TrimStart('\','/') -replace '\\','/'
    $srcDir = Split-Path -Parent $relSrc
    $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        foreach ($m in [regex]::Matches($line, $linkRegex)) {
            $target = $m.Groups[1].Value
            $anchor = $m.Groups[2].Value
            if (-not $anchor) { continue }   # no #anchor -> skip (file-only link)
            $checked++

            # Resolve target path relative to source file dir
            $targetNorm = $target -replace '\\','/'
            $targetPath = if ($targetNorm.StartsWith('/')) {
                $targetNorm.TrimStart('/')
            } elseif ($srcDir) {
                ($srcDir + '/' + $targetNorm) -replace '/+','/'
            } else {
                $targetNorm
            }
            # Normalize ./ and ../
            while ($targetPath -match '/\./') { $targetPath = $targetPath -replace '/\./','/' }
            while ($targetPath -match '(?m)^[^/]+/\.\./') { $targetPath = $targetPath -replace '^[^/]+/\.\./','' }

            if (-not $slugIndex.ContainsKey($targetPath)) {
                $violations += [pscustomobject]@{
                    Src = "$relSrc`:$($i+1)"; Link = "$target$anchor"; Issue = "target file not found ($targetPath)"
                }
                continue
            }
            $slug = $anchor.TrimStart('#')
            if (-not $slugIndex[$targetPath].Contains($slug)) {
                $violations += [pscustomobject]@{
                    Src = "$relSrc`:$($i+1)"; Link = "$target$anchor"; Issue = "anchor '$slug' not a heading slug in $targetPath"
                }
            }
        }
    }
}

Write-Host "[verify-md-anchors] checked $checked anchored links." -ForegroundColor Cyan
if ($violations.Count -eq 0) {
    Write-Host "[verify-md-anchors] OK — all anchored links resolve." -ForegroundColor Green
    exit 0
}
Write-Host ""
Write-Host "[verify-md-anchors] FAIL — $($violations.Count) broken link(s):" -ForegroundColor Red
foreach ($v in $violations) {
    [Console]::Error.WriteLine(("  {0}  {1}  -- {2}" -f $v.Src, $v.Link, $v.Issue))
}
exit 1
