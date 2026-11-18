#!/usr/bin/env bash
# lilly-blog 发布 TUI（Linux / WSL）
# 用法：./UPDATE.sh            打开菜单
#       ./UPDATE.sh --check    只跑一次构建验证
#       UPDATE_DRY_RUN=1 ...   只构建、不 commit/push（调试用）

set -u

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT" || exit 1

BLOG_DIR="src/content/blog"
PROJ_DIR="src/content/projects"
BASE_URL="${BLOG_BASE_URL:-https://xiaobin118.github.io/lilly-blog}"
DRY_RUN="${UPDATE_DRY_RUN:-0}"

if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
    C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_YELLOW=$'\033[33m'
else
    C_RESET=''; C_BOLD=''; C_DIM=''; C_CYAN=''; C_GREEN=''; C_RED=''; C_YELLOW=''
fi

say()  { printf '%s\n' "$*"; }
section() { printf '%s\n' "${C_CYAN}${C_BOLD}$*${C_RESET}"; }
warn() { printf '%s\n' "${C_YELLOW}$*${C_RESET}"; }
err()  { printf '%s\n' "${C_RED}$*${C_RESET}" >&2; }
pause(){ read -rp "按回车返回菜单..." _ || true; }

ask() {
    local prompt=$1 default=${2-} ans
    read -rp "$prompt${default:+ [$default]}: " ans || true
    printf '%s' "${ans:-$default}"
}

confirm() {
    local ans
    read -rp "$1 [y/N]: " ans || true
    [[ $ans == [yY] || $ans == [yY][eE][sS] ]]
}

# ---------- 构建：WSL 下 node_modules 是 Windows 版，走 Windows npm ----------
USE_WINDOWS_BUILD=0
detect_build_mode() {
    if [[ -d node_modules/@rollup/rollup-linux-x64-gnu || -d node_modules/@rollup/rollup-linux-arm64-gnu ]]; then
        USE_WINDOWS_BUILD=0
        return
    fi
    if [[ "$ROOT" == /mnt/* ]] && command -v powershell.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
        USE_WINDOWS_BUILD=1
    fi
}
detect_build_mode

build() {
    say ""
    section "=== 构建验证 ==="
    if (( USE_WINDOWS_BUILD )); then
        local winroot
        winroot=$(wslpath -w "$ROOT")
        powershell.exe -NoProfile -Command "Set-Location -LiteralPath '$winroot'; npm run build"
    else
        if ! command -v npm >/dev/null 2>&1; then
            err "找不到 npm。请先安装 Node.js，或在仓库里执行 npm install。"
            return 1
        fi
        npm run build
    fi
}

push_main() {
    if (( DRY_RUN )); then
        warn "[dry-run] 跳过 git push origin main"
        return 0
    fi
    say ""
    section "=== 推送到 GitHub ==="
    git push origin main
}

# ---------- 通用 ----------
project_ids() {
    find "$PROJ_DIR" -maxdepth 1 -name '*.md' -printf '%f\n' 2>/dev/null \
        | sed 's/\.md$//' | sort
}

esc_yaml() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    printf '%s' "$s"
}

# ---------- 1) 新文章 / 笔记 ----------
new_article() {
    say ""
    section "=== 发布新文章 / 笔记 ==="

    local src slug target
    read -r -e -p "源 .md 文件路径: " src || true
    [[ -z $src ]] && return 0
    src="${src/#\~/$HOME}"
    if [[ ! -f $src ]]; then
        err "文件不存在：$src"
        return 1
    fi
    if [[ $src != *.md ]]; then
        err "必须是 .md 文件。"
        return 1
    fi

    slug=$(basename "$src" .md)
    slug=$(ask "URL slug（小写字母/数字/连字符）" "$slug")
    if [[ ! $slug =~ ^[a-z0-9-]+$ ]]; then
        err "slug 只能包含小写字母、数字和连字符。"
        return 1
    fi

    target="$BLOG_DIR/$slug.md"
    if [[ -e $target ]] && ! confirm "覆盖已存在的 $target ?"; then
        return 0
    fi

    local content
    content=$(cat "$src")

    if [[ "$content" == ---* ]]; then
        say "检测到已有 frontmatter，保留原样（只更新文件并发布）。"
    else
        local title desc date tags tags_yaml type topic project
        local first_heading
        first_heading=$(printf '%s\n' "$content" | grep -m1 '^# ' | sed 's/^# //') || true

        title=$(ask "标题" "${first_heading:-$slug}")
        desc=$(ask "description（可留空）" "")

        while true; do
            date=$(ask "日期" "$(date +%F)")
            [[ $date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && break
            warn "日期格式应为 YYYY-MM-DD。"
        done

        while true; do
            tags=$(ask "tags（ASCII，逗号分隔）" "blog")
            if [[ $tags =~ ^[a-z0-9+_-]+([[:space:]]*,[[:space:]]*[a-z0-9+_-]+)*$ ]]; then
                break
            fi
            warn "tags 只能包含小写字母、数字、+、_、-，用逗号分隔。"
        done
        tags_yaml=$(printf '%s' "$tags" | sed 's/[[:space:]]*,[[:space:]]*/, /g')

        local type_choice
        type_choice=$(ask "类型 1=article 2=note 3=research" "1")
        case $type_choice in
            2) type=note ;;
            3) type=research ;;
            *) type=article ;;
        esac

        topic=""
        if [[ $type == note ]]; then
            topic=$(ask "topic（/notes 分组，可留空）" "")
        fi

        project=""
        local -a ids=()
        mapfile -t ids < <(project_ids)
        if ((${#ids[@]})); then
            say "关联项目（0 = 不关联）："
            local i=1
            for p in "${ids[@]}"; do
                printf '  %2d) %s\n' "$i" "$p"
                ((i++))
            done
            local pn
            pn=$(ask "选择项目" "0")
            if [[ $pn =~ ^[0-9]+$ ]] && (( pn > 0 && pn <= ${#ids[@]} )); then
                project=${ids[$((pn-1))]}
            fi
        fi

        local body
        body=$(printf '%s\n' "$content" | awk 'BEGIN{removed=0} { if (!removed && $0 ~ /^# /) { removed=1; next } print }' | sed '/./,$!d')

        local fm
        fm="---
title: \"$(esc_yaml "$title")\"
description: \"$(esc_yaml "$desc")\"
date: $date
tags: [$tags_yaml]
type: $type"
        [[ -n $topic ]] && fm+=$'\n'"topic: \"$(esc_yaml "$topic")\""
        [[ -n $project ]] && fm+=$'\n'"project: $project"
        fm+=$'\n---'

        printf '%s\n\n%s\n' "$fm" "$body" > "$target"
        say "已写入：$target"
    fi

    say ""
    say "--- 预览（前 25 行）---"
    sed -n '1,25p' "$target"
    say "------------------------"

    if ! confirm "构建并发布这篇内容？"; then
        warn "文件已保留在 $target，尚未提交。"
        return 0
    fi

    if ! build; then
        err "构建失败，未提交/推送。"
        say "文件保留在 $target；修复后可从菜单 2 发布。"
        return 1
    fi

    local title_for_msg
    title_for_msg=$(sed -n 's/^title:[[:space:]]*//p' "$target" | head -1 | sed 's/^"//; s/"$//')
    [[ -z $title_for_msg ]] && title_for_msg=$slug

    git add -- "$target" || return 1
    if (( DRY_RUN )); then
        warn "[dry-run] 跳过 git commit：post: $title_for_msg"
        return 0
    fi
    git commit -m "post: $title_for_msg" || { err "commit 失败（可能没有改动）。"; return 1; }
    if ! push_main; then
        err "推送失败。可手动执行：git push origin main"
        return 1
    fi

    say ""
    say "${C_GREEN}已发布：${BASE_URL}/post/${slug}/${C_RESET}"
}

# ---------- 2/3) 发布已有改动 ----------
publish_changes() {
    local dir=$1 label=$2
    say ""
    section "=== 发布已有 ${label} 改动 ==="

    local -a raw=()
    mapfile -t raw < <(git -c core.quotePath=false status --porcelain -- "$dir")
    if ((${#raw[@]} == 0)); then
        say "没有未提交的改动。"
        return 0
    fi

    local -a paths=() statuses=()
    local line status path
    for line in "${raw[@]}"; do
        [[ ${#line} -lt 4 ]] && continue
        status=${line:0:2}
        path=${line:3}
        path=${path%\"}; path=${path#\"}
        if [[ $path == *' -> '* ]]; then path=${path##* -> }; fi
        paths+=("$path")
        statuses+=("$status")
    done

    if ((${#paths[@]} == 0)); then
        say "没有可发布的改动。"
        return 0
    fi

    local i
    for ((i=0; i<${#paths[@]}; i++)); do
        printf '  %2d) %-2s %s\n' "$((i+1))" "${statuses[$i]}" "${paths[$i]}"
    done

    local sel
    read -rp "选择编号（空格分隔，a=全部，回车=取消）: " sel || true
    [[ -z $sel ]] && return 0

    local -a idx=()
    if [[ $sel == [aA] ]]; then
        for ((i=0; i<${#paths[@]}; i++)); do idx+=("$i"); done
    else
        read -ra nums <<< "$sel"
        local n
        for n in "${nums[@]}"; do
            [[ $n =~ ^[0-9]+$ ]] || continue
            (( n >= 1 && n <= ${#paths[@]} )) && idx+=("$((n-1))")
        done
    fi
    if ((${#idx[@]} == 0)); then
        warn "没有选中任何文件。"
        return 0
    fi

    if ! build; then
        err "构建失败，未提交/推送。"
        return 1
    fi

    local -a sel_paths=()
    for i in "${idx[@]}"; do sel_paths+=("${paths[$i]}"); done

    git add -A -- "${sel_paths[@]}" || return 1

    local msg
    if ((${#sel_paths[@]} == 1)); then
        msg="post: update $(basename "${sel_paths[0]}" .md)"
    else
        msg="post: update ${#sel_paths[@]} files"
    fi
    msg=$(ask "commit message" "$msg")

    if (( DRY_RUN )); then
        warn "[dry-run] 跳过 git commit/push：$msg"
        return 0
    fi

    git commit -m "$msg" || { err "commit 失败。"; return 1; }
    if ! push_main; then
        err "推送失败。可手动执行：git push origin main"
        return 1
    fi
    say "${C_GREEN}已推送：$msg${C_RESET}"
}

# ---------- 菜单 ----------
show_header() {
    clear 2>/dev/null || true
    local branch
    branch=$(git branch --show-current 2>/dev/null || echo '?')
    printf '%s\n' "${C_CYAN}${C_BOLD}================================================${C_RESET}"
    printf '%s\n' "${C_CYAN}${C_BOLD}  lilly-blog  发布工具（Linux / WSL）${C_RESET}"
    printf '%s\n' "${C_CYAN}${C_BOLD}================================================${C_RESET}"
    printf '  仓库: %s\n' "$ROOT"
    printf '  分支: %s\n' "$branch"
    if (( USE_WINDOWS_BUILD )); then
        printf '  %s\n' "${C_DIM}构建：WSL -> Windows npm（node_modules 是 win32 版）${C_RESET}"
    fi
    if (( DRY_RUN )); then
        printf '  %s\n' "${C_YELLOW}模式：dry-run（不提交/不推送）${C_RESET}"
    fi
    say ""
}

if [[ ${1-} == --help || ${1-} == -h ]]; then
    cat <<EOF
lilly-blog 发布 TUI

  ./UPDATE.sh            打开菜单
  ./UPDATE.sh --check    只构建验证
  UPDATE_DRY_RUN=1 ./UPDATE.sh   调试：只构建，不 commit/push

菜单：
  1) 发布新文章 / 笔记（从 .md 生成 frontmatter）
  2) 发布已有 blog 改动（勾选文件）
  3) 发布已有 project 改动（勾选文件）
  4) 仅构建检查
  5) 退出
EOF
    exit 0
fi

if [[ ${1-} == --check ]]; then
    build
    exit $?
fi

if ! command -v git >/dev/null 2>&1; then
    err "找不到 git。"
    exit 1
fi

while true; do
    show_header
    say "  1) 发布新文章 / 笔记"
    say "  2) 发布已有 blog 改动"
    say "  3) 发布已有 project 改动"
    say "  4) 仅构建检查"
    say "  5) 退出"
    say ""
    read -rp "请选择 [1-5]: " choice || exit 0
    case $choice in
        1) new_article ;;
        2) publish_changes "$BLOG_DIR" "blog" ;;
        3) publish_changes "$PROJ_DIR" "project" ;;
        4) if build; then say "${C_GREEN}构建通过。${C_RESET}"; else err "构建失败。"; fi ;;
        5) exit 0 ;;
        *) warn "无效选择。" ; sleep 0.6 ;;
    esac
    pause
done
