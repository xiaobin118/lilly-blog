<#
.SYNOPSIS
  lilly-blog 发布 TUI（Windows PowerShell）

.DESCRIPTION
  运行后打开交互菜单：
    1) 发布新文章 / 笔记（从 .md 生成 frontmatter）
    2) 发布已有 blog 改动（勾选文件）
    3) 发布已有 project 改动（勾选文件）
    4) 仅构建检查
    5) 退出

  构建验证通过后才会 commit + push；构建失败时不会提交。

.EXAMPLE
  .\UPDATE.ps1            打开菜单
  .\UPDATE.ps1 -Check     只构建验证
  .\UPDATE.ps1 -DryRun    只构建，不 commit/push（调试）
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Set-Location $Root
$BlogDir = Join-Path $Root 'src\content\blog'
$ProjDir = Join-Path $Root 'src\content\projects'
$BaseUrl = if ($env:BLOG_BASE_URL) { $env:BLOG_BASE_URL } else { 'https://xiaobin118.github.io/lilly-blog' }

# ---------- 通用 ----------
function Show-Header {
    Clear-Host
    $branch = (& git branch --show-current 2>$null)
    if (-not $branch) { $branch = '?' }
    Write-Host '================================================' -ForegroundColor Cyan
    Write-Host '  lilly-blog  发布工具（Windows）' -ForegroundColor Cyan
    Write-Host '================================================' -ForegroundColor Cyan
    Write-Host "  仓库: $Root"
    Write-Host "  分支: $branch"
    if ($DryRun) { Write-Host '  模式: dry-run（不提交/不推送）' -ForegroundColor Yellow }
    Write-Host ''
}

function Ask {
    param([string]$Prompt, [string]$Default = '')
    $suffix = if ($Default) { " [$Default]" } else { '' }
    $value = Read-Host "$Prompt$suffix"
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value.Trim()
}

function Confirm {
    param([string]$Message)
    $ans = Read-Host "$Message [y/N]"
    return ($ans -match '^(y|yes)$')
}

function Escape-Yaml {
    param([string]$Text)
    return ($Text -replace '\\', '\\' -replace '"', '\"')
}

function Get-ProjectIds {
    if (-not (Test-Path -LiteralPath $ProjDir)) { return @() }
    return @(
        Get-ChildItem -LiteralPath $ProjDir -Filter '*.md' -File |
            Sort-Object Name |
            ForEach-Object { $_.BaseName }
    )
}

function Invoke-Build {
    Write-Host "`n=== 构建验证 ===" -ForegroundColor Cyan
    & npm run build
    return ($LASTEXITCODE -eq 0)
}

function Invoke-Push {
    if ($DryRun) {
        Write-Host '[dry-run] 跳过 git push origin main' -ForegroundColor Yellow
        return $true
    }
    Write-Host "`n=== 推送到 GitHub ===" -ForegroundColor Cyan
    & git push origin main
    return ($LASTEXITCODE -eq 0)
}

function Get-Changes {
    param([string]$Dir)
    $lines = @(& git -c core.quotePath=false status --porcelain -- $Dir 2>$null)
    $result = @()
    foreach ($line in $lines) {
        if ($line.Length -lt 4) { continue }
        $status = $line.Substring(0, 2)
        $path = $line.Substring(3).Trim()
        if ($path -match ' -> ') { $path = ($path -split ' -> ')[-1] }
        $path = $path.Trim('"')
        $result += [pscustomobject]@{ Status = $status; Path = $path }
    }
    return $result
}

function Select-Changes {
    param($Changes)
    for ($i = 0; $i -lt $Changes.Count; $i++) {
        Write-Host ("  {0,2}) {1}  {2}" -f ($i + 1), $Changes[$i].Status, $Changes[$i].Path)
    }
    $sel = Read-Host '选择编号（空格分隔，a=全部，回车=取消）'
    if ([string]::IsNullOrWhiteSpace($sel)) { return @() }
    if ($sel -match '^[aA]$') { return @($Changes | ForEach-Object { $_.Path }) }

    $picked = @()
    foreach ($token in ($sel -split '\s+')) {
        if ($token -match '^\d+$') {
            $n = [int]$token
            if ($n -ge 1 -and $n -le $Changes.Count) { $picked += $Changes[$n - 1].Path }
        }
    }
    return $picked
}

# ---------- 发布已有改动 ----------
function Publish-Changes {
    param([string]$Dir, [string]$Label)

    Write-Host "`n=== 发布已有 $Label 改动 ===" -ForegroundColor Cyan
    $changes = @(Get-Changes $Dir)
    if ($changes.Count -eq 0) {
        Write-Host '没有未提交的改动。' -ForegroundColor Yellow
        return
    }

    $paths = @(Select-Changes $changes)
    if ($paths.Count -eq 0) { return }

    if (-not (Invoke-Build)) {
        Write-Host '构建失败，未提交/推送。' -ForegroundColor Red
        return
    }

    & git add -A -- $paths
    if ($LASTEXITCODE -ne 0) { Write-Host 'git add 失败。' -ForegroundColor Red; return }

    if ($paths.Count -eq 1) {
        $defaultMsg = "post: update $([IO.Path]::GetFileNameWithoutExtension($paths[0]))"
    } else {
        $defaultMsg = "post: update $($paths.Count) files"
    }
    $msg = Ask 'commit message' $defaultMsg

    if ($DryRun) {
        Write-Host "[dry-run] 跳过 git commit/push：$msg" -ForegroundColor Yellow
        return
    }

    & git commit -m $msg
    if ($LASTEXITCODE -ne 0) { Write-Host 'commit 失败（可能没有改动）。' -ForegroundColor Red; return }
    if (-not (Invoke-Push)) {
        Write-Host '推送失败。可手动执行：git push origin main' -ForegroundColor Red
        return
    }
    Write-Host "已推送：$msg" -ForegroundColor Green
}

# ---------- 新文章 / 笔记 ----------
function New-Article {
    Write-Host "`n=== 发布新文章 / 笔记 ===" -ForegroundColor Cyan

    $src = Ask '源 .md 文件路径'
    if ([string]::IsNullOrWhiteSpace($src)) { return }
    $src = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($src)
    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
        Write-Host "文件不存在：$src" -ForegroundColor Red
        return
    }
    if ([IO.Path]::GetExtension($src) -ne '.md') {
        Write-Host '必须是 .md 文件。' -ForegroundColor Red
        return
    }

    $slug = [IO.Path]::GetFileNameWithoutExtension($src)
    $slug = Ask 'URL slug（小写字母/数字/连字符）' $slug
    if ($slug -notmatch '^[a-z0-9-]+$') {
        Write-Host 'slug 只能包含小写字母、数字和连字符。' -ForegroundColor Red
        return
    }

    $target = Join-Path $BlogDir "$slug.md"
    if ((Test-Path -LiteralPath $target) -and -not (Confirm "覆盖已存在的 $target ?")) { return }

    $content = Get-Content -LiteralPath $src -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($content)) {
        Write-Host '源文件为空。' -ForegroundColor Red
        return
    }

    $trimmed = $content.TrimStart()
    if ($trimmed.StartsWith('---')) {
        Write-Host '检测到已有 frontmatter，保留原样（只更新文件并发布）。' -ForegroundColor Yellow
        $out = $content
    } else {
        $m = [regex]::Match($content, '(?m)^#\s+(.+)$')
        $defaultTitle = if ($m.Success) { $m.Groups[1].Value.Trim() } else { $slug }

        $title = Ask '标题' $defaultTitle
        $desc = Ask 'description（可留空）'

        do {
            $date = Ask '日期' (Get-Date -Format 'yyyy-MM-dd')
            if ($date -notmatch '^\d{4}-\d{2}-\d{2}$') { Write-Host '日期格式应为 YYYY-MM-DD。' -ForegroundColor Yellow }
        } until ($date -match '^\d{4}-\d{2}-\d{2}$')

        do {
            $tags = Ask 'tags（ASCII，逗号分隔）' 'blog'
            if ($tags -notmatch '^[a-z0-9+_-]+(\s*,\s*[a-z0-9+_-]+)*$') {
                Write-Host 'tags 只能包含小写字母、数字、+、_、-，用逗号分隔。' -ForegroundColor Yellow
            }
        } until ($tags -match '^[a-z0-9+_-]+(\s*,\s*[a-z0-9+_-]+)*$')
        $tagsYaml = $tags -replace '\s*,\s*', ', '

        $typeChoice = Ask '类型 1=article 2=note 3=research' '1'
        switch ($typeChoice) {
            '2' { $type = 'note' }
            '3' { $type = 'research' }
            default { $type = 'article' }
        }

        $topic = ''
        if ($type -eq 'note') { $topic = Ask 'topic（/notes 分组，可留空）' }

        $project = ''
        $projectIds = @(Get-ProjectIds)
        if ($projectIds.Count -gt 0) {
            Write-Host '关联项目（0 = 不关联）：'
            for ($i = 0; $i -lt $projectIds.Count; $i++) {
                Write-Host ("  {0,2}) {1}" -f ($i + 1), $projectIds[$i])
            }
            $pn = Ask '选择项目' '0'
            if ($pn -match '^\d+$') {
                $n = [int]$pn
                if ($n -ge 1 -and $n -le $projectIds.Count) { $project = $projectIds[$n - 1] }
            }
        }

        $fm = "---`ntitle: `"$(Escape-Yaml $title)`"`ndescription: `"$(Escape-Yaml $desc)`"`ndate: $date`ntags: [$tagsYaml]`ntype: $type"
        if ($topic) { $fm += "`ntopic: `"$(Escape-Yaml $topic)`"" }
        if ($project) { $fm += "`nproject: $project" }
        $fm += "`n---`n`n"

        $bodyLines = @()
        $removedHeading = $false
        foreach ($line in ($trimmed -split "`r?`n")) {
            if (-not $removedHeading -and $line -match '^#\s+') { $removedHeading = $true; continue }
            $bodyLines += $line
        }
        $body = ($bodyLines -join "`n").TrimStart("`n")
        $out = $fm + $body
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($target, $out, $utf8NoBom)
    Write-Host "已写入：$target"

    Write-Host "`n--- 预览（前 25 行）---"
    Get-Content -LiteralPath $target -TotalCount 25
    Write-Host '------------------------'

    if (-not (Confirm '构建并发布这篇内容？')) {
        Write-Host "文件已保留在 $target，尚未提交。" -ForegroundColor Yellow
        return
    }

    if (-not (Invoke-Build)) {
        Write-Host '构建失败，未提交/推送。' -ForegroundColor Red
        Write-Host "文件保留在 $target；修复后可从菜单 2 发布。"
        return
    }

    $titleMatch = [regex]::Match($out, '(?m)^title:\s*"?([^"\r\n]+)"?\s*$')
    $titleForMsg = if ($titleMatch.Success) { $titleMatch.Groups[1].Value.Trim() } else { $slug }

    & git add -- $target
    if ($LASTEXITCODE -ne 0) { Write-Host 'git add 失败。' -ForegroundColor Red; return }

    if ($DryRun) {
        Write-Host "[dry-run] 跳过 git commit：post: $titleForMsg" -ForegroundColor Yellow
        return
    }

    & git commit -m "post: $titleForMsg"
    if ($LASTEXITCODE -ne 0) { Write-Host 'commit 失败（可能没有改动）。' -ForegroundColor Red; return }
    if (-not (Invoke-Push)) {
        Write-Host '推送失败。可手动执行：git push origin main' -ForegroundColor Red
        return
    }

    Write-Host "`n已发布：$BaseUrl/post/$slug/" -ForegroundColor Green
}

# ---------- 入口 ----------
if ($Check) {
    if (Invoke-Build) { exit 0 } else { exit 1 }
}

while ($true) {
    Show-Header
    Write-Host '  1) 发布新文章 / 笔记'
    Write-Host '  2) 发布已有 blog 改动'
    Write-Host '  3) 发布已有 project 改动'
    Write-Host '  4) 仅构建检查'
    Write-Host '  5) 退出'
    Write-Host ''
    $choice = Read-Host '请选择 [1-5]'

    switch ($choice) {
        '1' { New-Article }
        '2' { Publish-Changes -Dir $BlogDir -Label 'blog' }
        '3' { Publish-Changes -Dir $ProjDir -Label 'project' }
        '4' {
            if (Invoke-Build) { Write-Host '构建通过。' -ForegroundColor Green }
            else { Write-Host '构建失败。' -ForegroundColor Red }
        }
        '5' { return }
        default { Write-Host '无效选择。' -ForegroundColor Yellow; Start-Sleep -Milliseconds 600 }
    }

    if ($choice -ne '5') { Read-Host '按回车返回菜单...' | Out-Null }
}
