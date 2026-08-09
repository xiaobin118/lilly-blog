<#
.SYNOPSIS
  发布或更新静态博客文章,构建验证后自动推送部署。
.DESCRIPTION
  两种用法:
  1) 新增/更新文章(带参数):
     .\UPDATE.ps1 <文章.md> [-Tags a,b] [-Title "标题"] [-Date 2026-08-07]
     - 若无 frontmatter,自动根据标题/日期/标签生成
     - 复制到 src/content/blog/<文件名>.md(文件名即 URL slug)
     - 若文件名与已有文章相同,则覆盖更新
  2) 检测博客内改动(无参数):
     .\UPDATE.ps1
     - 检测 src/content/blog 的未提交改动(直接编辑文章文本后运行)
     - 构建验证 → 提交 → 推送
.EXAMPLE
  .\UPDATE.ps1 .\posts\how-i-learned-cpp.md -Tags cpp,learning
  # 直接编辑了 src/content/blog/*.md 后:
  .\UPDATE.ps1
#>
param(
  [Parameter(Position = 0)]
  [string]$ArticlePath = '',
  [string]$Title = '',
  [string]$Tags = 'blog',
  [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# ========== 模式 2: 检测博客内改动并推送 ==========
if (-not $ArticlePath) {
  $changed = git status --porcelain -- src/content/blog/
  if (-not $changed) {
    Write-Host "src/content/blog 没有未提交的改动,无需更新。"
    exit 0
  }
  Write-Host "检测到以下改动:"
  $changed
  $files = @($changed | ForEach-Object { ($_ -split '\s+', 2)[1].Trim() })
  $msg = if ($files.Count -eq 1) {
    "post: update $([System.IO.Path]::GetFileNameWithoutExtension($files[0]))"
  } else {
    "chore: update $($files.Count) blog posts"
  }
  Write-Host "`n=== 构建验证 ==="
  npm run build
  if ($LASTEXITCODE -ne 0) { throw "构建失败,未提交/推送。请检查文章内容。" }
  git add src/content/blog/
  git commit -m $msg
  git push origin main
  Write-Host "`n已推送博客更新: $msg"
  exit 0
}

# ========== 模式 1: 新增 / 覆盖更新文章 ==========
# 1. 验证文章文件
if (-not (Test-Path -LiteralPath $ArticlePath)) { throw "找不到文件: $ArticlePath" }
if ((Get-Item -LiteralPath $ArticlePath).Extension -ne '.md') { throw "必须是 .md 文件" }

# 2. slug = 文件名(将用作 URL),仅允许英文/数字/连字符
$slug = [System.IO.Path]::GetFileNameWithoutExtension($ArticlePath)
if ($slug -notmatch '^[A-Za-z0-9-]+$') {
  throw "文件名 '$slug' 需为英文/数字/连字符(将用作 URL slug),请重命名后再运行。"
}

# 3. 读取内容
$content = Get-Content -LiteralPath $ArticlePath -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($content)) { throw "文章内容为空" }

# 4. 检查是否已有 frontmatter(以 --- 开头)
$trimmed = $content.TrimStart()
$hasFrontmatter = $trimmed.StartsWith('---')

# 5. 提取标题(优先级: -Title 参数 > 已有 title: > 第一个 # 标题 > slug)
if (-not $Title) {
  if ($content -match '^---\s*$[\s\S]*?^title:\s*"?([^"\r\n]+?)"?\s*$') { $Title = $Matches[1].Trim() }
  elseif ($content -match '(?m)^#\s+(.+)$') { $Title = $Matches[1].Trim() }
  else { $Title = $slug }
}

# 6. 若无 frontmatter,自动生成并插入
if (-not $hasFrontmatter) {
  $titleEscaped = $Title.Replace('"', '\"')
  $tagsJoined = (($Tags -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ', '
  $fm = @"
---
title: "$titleEscaped"
date: $Date
tags: [$tagsJoined]
---
"@
  $content = $fm + "`n`n" + $trimmed
  Write-Host "已自动生成 frontmatter(title=$Title, date=$Date, tags=[$tagsJoined])"
} else {
  Write-Host "检测到已有 frontmatter,保留原样"
}

# 7. 写入博客目录(文件名即 slug)
$destFile = Join-Path $PSScriptRoot "src\content\blog\$slug.md"
Set-Content -LiteralPath $destFile -Value $content -Encoding UTF8 -NoNewline
$isUpdate = Test-Path -LiteralPath $destFile
Write-Host "已写入: $destFile"

# 8. 构建验证
Write-Host "`n=== 构建验证 ==="
npm run build
if ($LASTEXITCODE -ne 0) { throw "构建失败,未提交/推送。请检查文章内容。" }
Write-Host "构建通过。"

# 9. 提交并推送
git add "src/content/blog/$slug.md"
git commit -m "post: $Title"
git push origin main
Write-Host "`n已推送 '$Title' → https://xiaobin118.github.io/lilly-blog/post/$slug/"
Write-Host "GitHub Actions 将自动构建部署,几分钟后可访问。"
