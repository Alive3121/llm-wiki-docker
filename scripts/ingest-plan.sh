#!/bin/bash
# Ingest Planner — 读 Raw Diff Report(JSON),做影响面分析,产出 Ingest Task List
# 影响面分析只发生在这一步(Analyzer/raw-diff.sh 只管 git 差分):
#   变更 raw 路径 → atoms 的 source_ids 反查受影响 atoms → wiki 页脚反查受影响页面
#
# 用法: ./scripts/ingest-plan.sh [raw-diff-report-<日期时分>.json]
#       不带参数时取仓库根目录下最新一份
#
# 产出: ingest-task-list-<日期时分>.md — 任务清单即工作队列,可分批消化;
#       中断后重跑 raw-diff.sh + 本脚本即可续跑(基线标签未动,
#       已处理的 added 文件会被标注"已有 atoms 引用")

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO" || exit 1

JSON="${1:-}"
if [ -z "$JSON" ]; then
  JSON="$(ls -t raw-diff-report-*.json 2>/dev/null | head -1)"
fi
if [ -z "$JSON" ] || [ ! -f "$JSON" ]; then
  echo "ERROR: no raw-diff-report-*.json found. Run ./scripts/raw-diff.sh first." >&2
  exit 1
fi

STAMP="$(basename "$JSON" .json)"
STAMP="${STAMP#raw-diff-report-}"
OUT="ingest-task-list-${STAMP}.md"
BASELINE="$(sed -n 's/.*"baseline_commit": "\([^"]*\)".*/\1/p' "$JSON" | head -1)"

# ─── JSON 字段抽取(报告由 raw-diff.sh 写出,固定一行一条 entry)───
jfield() { # jfield <line> <key> — 取 "key":"value",还原 \" 与 \\ 转义
  printf '%s\n' "$1" | awk -v k="$2" '{
    pat = "\"" k "\":\""
    i = index($0, pat); if (!i) exit
    s = substr($0, i + length(pat)); out = ""
    for (j = 1; j <= length(s); j++) {
      c = substr(s, j, 1)
      if (c == "\\") { j++; out = out substr(s, j, 1); continue }
      if (c == "\"") break
      out = out c
    }
    print out
  }'
}

# ─── 影响面反查 ───
find_atoms() { # $1 = raw 路径 → 输出 "atom-id<TAB>atom-file" 行(排除 _archive 与模板)
  local path="$1"
  [ -n "$path" ] || return 0
  grep -rlF -- "$path" atoms 2>/dev/null | grep -v '/_archive/' | grep -v '_template' |
  while IFS= read -r f; do
    printf '%s\t%s\n' "$(sed -n 's/^id:[[:space:]]*//p' "$f" | head -1)" "$f"
  done
}

find_wiki() { # $1 = atom id → 输出受影响 wiki 页 slug(优先页脚反引号格式,兜底裸 id)
  local id="$1"
  [ -n "$id" ] || return 0
  local hits
  hits="$(grep -rlF -- "\`${id}\`" wiki 2>/dev/null | grep -v '_template')"
  [ -z "$hits" ] && hits="$(grep -rlF -- "$id" wiki 2>/dev/null | grep -v '_template')"
  printf '%s\n' "$hits" | sed 's|^wiki/||; s|\.md$||' | grep -v '^$'
}

join_ids() { # stdin: 每行一个 id → `id1`, `id2`, ...
  sed 's/^/`/; s/$/`/' | tr '\n' ',' | sed 's/,$//; s/,/, /g'
}

# ─── 主循环:按分类累积任务块 ───
SEC_ADDED=() SEC_REINGEST=() SEC_RENAME=() SEC_ARCHIVE=() SEC_VIOLATION=()
declare -A WIKI_ALL

collect_wiki() { # stdin: 每行一个 atom id → 输出去重后的受影响 wiki 页列表
  declare -A seen
  local id page
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    while IFS= read -r page; do
      [ -n "$page" ] || continue
      seen["$page"]=1
    done < <(find_wiki "$id")
  done
  printf '%s\n' "${!seen[@]}" | grep -v '^$' | sort
}

while IFS= read -r line; do
  cat="$(jfield "$line" category)"
  case "$cat" in
    added)
      path="$(jfield "$line" path)"
      atoms="$(find_atoms "$path")"
      chunk="- [ ] \`${path}\`"
      if [ -n "$atoms" ]; then
        ids="$(printf '%s\n' "$atoms" | cut -f1 | join_ids)"
        chunk+=$'\n'"  - ⚠ 已有 atoms 引用(可能上一批已处理,复核后可跳过): ${ids}"
      fi
      SEC_ADDED+=("$chunk")
      ;;
    modified|rename_modified)
      if [ "$cat" = "modified" ]; then
        path="$(jfield "$line" path)"
        lookup="$path"
        chunk="- [ ] \`${path}\`"
      else
        from="$(jfield "$line" from)"
        to="$(jfield "$line" to)"
        lookup="$from"
        chunk="- [ ] \`${from}\` → \`${to}\`(rename+modified:先把下列 atoms 的 source_ids 改为新路径)"
      fi
      atoms="$(find_atoms "$lookup")"
      if [ -n "$atoms" ]; then
        ids="$(printf '%s\n' "$atoms" | cut -f1 | join_ids)"
        chunk+=$'\n'"  - 受影响 atoms: ${ids}"
        pages="$(printf '%s\n' "$atoms" | cut -f1 | collect_wiki)"
        if [ -n "$pages" ]; then
          chunk+=$'\n'"  - 受影响 wiki 页: $(printf '%s\n' "$pages" | join_ids)"
          while IFS= read -r pg; do
            [ -n "$pg" ] && WIKI_ALL["$pg"]=1
          done <<< "$pages"
        fi
      else
        chunk+=$'\n'"  - 无 atoms 引用(此前未 Ingest?)→ 按 Added 处理"
      fi
      SEC_REINGEST+=("$chunk")
      ;;
    rename_only)
      from="$(jfield "$line" from)"
      to="$(jfield "$line" to)"
      atoms="$(find_atoms "$from")"
      chunk="- [ ] \`${from}\` → \`${to}\`"
      if [ -n "$atoms" ]; then
        ids="$(printf '%s\n' "$atoms" | cut -f1 | join_ids)"
        chunk+=$'\n'"  - 修正下列 atoms 的 source_ids 路径(仅元数据,正文不动): ${ids}"
      else
        chunk+=$'\n'"  - 无 atoms 引用,无需处理"
      fi
      SEC_RENAME+=("$chunk")
      ;;
    soft_deleted)
      from="$(jfield "$line" from)"
      to="$(jfield "$line" to)"
      lookup="$from"; [ -z "$lookup" ] && lookup="$(basename "$to")"
      atoms="$(find_atoms "$lookup")"
      if [ -n "$from" ]; then
        chunk="- [ ] \`${from}\` → \`${to}\`"
      else
        chunk="- [ ] \`${to}\`(直接位于 _archive/,无对应删除记录)"
      fi
      if [ -n "$atoms" ]; then
        ids="$(printf '%s\n' "$atoms" | cut -f1 | join_ids)"
        chunk+=$'\n'"  - 引用中的 atoms(默认保留;确属作废才走 superseded_by + _archive/): ${ids}"
      else
        chunk+=$'\n'"  - 无 atoms 引用,归档即完成"
      fi
      SEC_ARCHIVE+=("$chunk")
      ;;
    hard_deleted)
      path="$(jfield "$line" path)"
      SEC_VIOLATION+=("- [ ] \`${path}\` ⚠ 恢复(\`git checkout -- '${path}'\`)或移入 \`raw/_archive/\`,再重跑差分")
      ;;
  esac
done < <(grep '"category"' "$JSON")

# ─── 输出任务清单 ───
print_section() { # $1 = 数组名
  local -n arr="$1"
  if [ ${#arr[@]} -eq 0 ]; then
    echo "None."
  else
    local chunk
    for chunk in "${arr[@]}"; do printf '%s\n' "$chunk"; done
  fi
  echo ""
}

{
  echo "# Ingest Task List"
  echo ""
  echo "> Generated: $(date '+%Y-%m-%d %H:%M')"
  echo "> Source report: \`${JSON}\`(baseline \`last-ingest\`@${BASELINE} → working tree)"
  echo ""
  echo "| Branch | Count |"
  echo "|--------|-------|"
  echo "| Added → Create Atom | ${#SEC_ADDED[@]} |"
  echo "| Modified / Rename+Modify → Re-Ingest | ${#SEC_REINGEST[@]} |"
  echo "| Rename Only → Update Metadata | ${#SEC_RENAME[@]} |"
  echo "| Deleted → Archive | ${#SEC_ARCHIVE[@]} |"
  echo "| Violations (hard-deleted) | ${#SEC_VIOLATION[@]} |"
  echo ""

  echo "## Added → Create Atom"
  echo ""
  echo "正常 Ingest → 新 atoms。"
  echo ""
  print_section SEC_ADDED

  echo "## Modified / Rename+Modify → Re-Ingest(Regen + Diff)"
  echo ""
  echo "重新 Ingest 生成候选 atoms → 与现有 atoms 做 git diff(忽略 \`created\` 等随生成时间"
  echo "变化的字段)→ 无差分则 skip(丢弃候选、保留原 atom);有差分则新 atom +"
  echo "\`superseded_by\` + 旧 atom 入 \`_archive/\`。"
  echo ""
  print_section SEC_REINGEST

  echo "## Rename Only → Update Metadata"
  echo ""
  echo "R100 纯改名:只修受影响 atoms 的 \`source_ids\` 路径,atom 正文不动,不重新 Ingest。"
  echo ""
  print_section SEC_RENAME

  echo "## Deleted → Archive"
  echo ""
  echo "raw 原文已在 \`raw/_archive/\`,git 历史完整,DeepQuery 仍可验证到 raw 层。"
  echo "atoms 默认保留不动,内容确属作废才走归档生命周期。"
  echo ""
  print_section SEC_ARCHIVE

  echo "## Violations(hard-deleted — 先处理再消化队列)"
  echo ""
  print_section SEC_VIOLATION

  echo "## Incremental Wiki Update(受影响 wiki 页汇总)"
  echo ""
  if [ ${#WIKI_ALL[@]} -eq 0 ]; then
    echo "None."
  else
    for page in $(printf '%s\n' "${!WIKI_ALL[@]}" | sort); do
      echo "- [[${page}]]"
    done
  fi
  echo ""

  echo "---"
  echo ""
  echo "**收尾**:任务清空后依次 \`./scripts/gen-index.sh\` → \`./scripts/log-append.sh\` →"
  echo "(动了 wiki 时)\`./scripts/lint.sh\`,commit 本轮变更,最后 \`git tag -f last-ingest\`"
  echo "把基线标签移到本次 commit。"
} > "$OUT"

TOTAL=$(( ${#SEC_ADDED[@]} + ${#SEC_REINGEST[@]} + ${#SEC_RENAME[@]} + ${#SEC_ARCHIVE[@]} + ${#SEC_VIOLATION[@]} ))
echo "Ingest plan complete: ${TOTAL} task(s), ${#WIKI_ALL[@]} wiki page(s) affected."
echo "  Task list: ${OUT}"
if [ ${#SEC_VIOLATION[@]} -gt 0 ]; then
  echo "WARNING: ${#SEC_VIOLATION[@]} hard-deleted violation(s) — handle before working the queue." >&2
fi
