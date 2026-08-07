<#
.SYNOPSIS
  添加一篇 Markdown 文章到静态博客并自动部署。
.DESCRIPTION
  用法: .\UPDATE.ps1 <文章.md> [-Tags a,b] [-Title "标题"] [-Date 2026-08-07]
  - 若无 frontmatter,自动根据标题/日期/标签生成
  - 复制到 src/content/blog/<文件名>.md(文件名即 URL slug)
  - npm run build 验证 → git commit → push origin main(GitHub Actions 自动发布)
.EXAMPLE
  .\UPDATE.ps1 .\posts\how-i-learned-cpp.md -Tags cpp,learning
#>
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$ArticlePath,
  [string]$Title = '',
  [string]$Tags = 'blog',
  [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

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
