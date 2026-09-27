#!/bin/bash
# Raw Diff — Git Change Analyzer + Raw Diff Report
# 纯 git 差分:以 last-ingest 标签为基线,git diff -M(rename 侦测内建)+ 未跟踪文件扫描,
# 比较对象是当前工作区。只回答"哪些 raw 文件发生了什么变化",不做影响面分析
# (影响面分析 → scripts/ingest-plan.sh)。
#
# 产出(双格式):
#   raw-diff-report-<日期时分>.md    人读
#   raw-diff-report-<日期时分>.json  机器可读,供 ingest-plan.sh 消费
#
# 分类:added / modified / rename-only(R100)/ rename+modified(R<100)/
#       soft-deleted(移入 raw/_archive/)/ hard-deleted(违规,exit 1)
#
# 基线前移不归本脚本管:一批处理完并 commit 后,手动执行 git tag -f last-ingest

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO" || exit 1

BASELINE_TAG="last-ingest"

if ! git rev-parse -q --verify "${BASELINE_TAG}^{commit}" >/dev/null; then
  echo "ERROR: baseline tag '${BASELINE_TAG}' not found." >&2
  echo "Create it on the last fully-ingested commit first:" >&2
  echo "  git tag ${BASELINE_TAG} <commit>" >&2
  exit 1
fi
BASELINE_COMMIT="$(git rev-parse --short "${BASELINE_TAG}")"

STAMP="$(date '+%Y-%m-%d-%H%M')"
REPORT_MD="raw-diff-report-${STAMP}.md"
REPORT_JSON="raw-diff-report-${STAMP}.json"

ADDED=()        # path
MODIFIED=()     # path
RENAME_ONLY=()  # from \t to \t similarity
RENAME_MOD=()   # from \t to \t similarity
SOFT_DEL=()     # from \t to(from 为空 = 文件直接出现在 _archive/,无对应删除记录)
HARD_DEL=()     # path
PENDING_D=()    # 删除记录,待与 raw/_archive/ 配对

# ─── 1. 未跟踪文件扫描:git add -N(intent-to-add,只登记路径不暂存内容)───
# 不这样做的话,普通 mv 改名的新路径是 untracked,git diff -M 配不上对,
# 会把一次改名误判成 hard-deleted + added。diff 结束后由 trap 精确还原。
ITA_PATHS=()
while IFS= read -r -d '' p; do ITA_PATHS+=("$p"); done \
  < <(git ls-files --others --exclude-standard -z -- raw/)

cleanup() {
  if [ ${#ITA_PATHS[@]} -gt 0 ]; then
    printf '%s\0' "${ITA_PATHS[@]}" | xargs -0 git reset -q -- 2>/dev/null
  fi
}
trap cleanup EXIT

if [ ${#ITA_PATHS[@]} -gt 0 ]; then
  printf '%s\0' "${ITA_PATHS[@]}" | xargs -0 git add -N --
fi

# ─── 2. git 差分:working tree vs 基线标签,NUL 分隔以兼容空格/CJK 文件名 ───
while IFS= read -r -d '' status; do
  case "$status" in
    R*)
      IFS= read -r -d '' from && IFS= read -r -d '' to || break
      sim="$(( 10#${status#R} ))"   # R098 → 98(去前导零,否则 JSON 数字非法)
      if [[ "$to" == raw/_archive/* ]]; then
        SOFT_DEL+=("${from}"$'\t'"${to}")
      elif [ "$sim" = "100" ]; then
        RENAME_ONLY+=("${from}"$'\t'"${to}"$'\t'"${sim}")
      else
        RENAME_MOD+=("${from}"$'\t'"${to}"$'\t'"${sim}")
      fi
      ;;
    C*)
      IFS= read -r -d '' from && IFS= read -r -d '' to || break
      ADDED+=("$to")
      ;;
    *)
      IFS= read -r -d '' path || break
      case "$status" in
        A)
          if [[ "$path" == raw/_archive/* ]]; then
            SOFT_DEL+=($'\t'"${path}")
          else
            ADDED+=("$path")
          fi
          ;;
        M|T) MODIFIED+=("$path") ;;
        D)   PENDING_D+=("$path") ;;
      esac
      ;;
  esac
done < <(git diff -M --name-status -z "${BASELINE_TAG}" -- raw/)

# ─── 3. 删除配对兜底:rename 侦测没配上时,D + _archive/ 内同名文件 = 软删除;
#        配不上 = 硬删除(违规)───
for path in "${PENDING_D[@]}"; do
  base="$(basename "$path")"
  archived=""
  if [ -e "raw/_archive/${base}" ]; then
    archived="raw/_archive/${base}"
  else
    while IFS= read -r -d '' f; do
      if [ "$(basename "$f")" = "$base" ]; then archived="$f"; break; fi
    done < <(find raw/_archive -type f -print0 2>/dev/null)
  fi
  if [ -n "$archived" ]; then
    SOFT_DEL+=("${path}"$'\t'"${archived}")
  else
    HARD_DEL+=("$path")
  fi
done

# ─── 4. Raw Diff Report(Markdown,人读)───
{
  echo "# Raw Diff Report"
  echo ""
  echo "> Generated: $(date '+%Y-%m-%d %H:%M')"
  echo "> Baseline: \`${BASELINE_TAG}\` (${BASELINE_COMMIT}) → working tree(git diff -M + untracked scan)"
  echo "> Machine-readable: \`${REPORT_JSON}\`(供 ingest-plan.sh 消费)"
  echo ""
  echo "| Category | Count |"
  echo "|----------|-------|"
  echo "| added | ${#ADDED[@]} |"
  echo "| modified | ${#MODIFIED[@]} |"
  echo "| rename-only (R100) | ${#RENAME_ONLY[@]} |"
  echo "| rename+modified (R<100) | ${#RENAME_MOD[@]} |"
  echo "| soft-deleted (raw/_archive/) | ${#SOFT_DEL[@]} |"
  echo "| hard-deleted (violation) | ${#HARD_DEL[@]} |"
  echo ""

  echo "## Added(新增 → Create Atom)"
  echo ""
  if [ ${#ADDED[@]} -eq 0 ]; then echo "None."; fi
  for p in "${ADDED[@]}"; do echo "- \`${p}\`"; done
  echo ""

  echo "## Modified(修改 → Re-Ingest:Regen + Diff)"
  echo ""
  if [ ${#MODIFIED[@]} -eq 0 ]; then echo "None."; fi
  for p in "${MODIFIED[@]}"; do echo "- \`${p}\`"; done
  echo ""

  echo "## Rename Only(纯改名 R100 → Update Metadata)"
  echo ""
  if [ ${#RENAME_ONLY[@]} -eq 0 ]; then echo "None."; fi
  for e in "${RENAME_ONLY[@]}"; do
    IFS=$'\t' read -r from to sim <<< "$e"
    echo "- \`${from}\` → \`${to}\`"
  done
  echo ""

  echo "## Rename + Modified(改名且内容变更 R<100 → 修 source_ids 后 Re-Ingest)"
  echo ""
  if [ ${#RENAME_MOD[@]} -eq 0 ]; then echo "None."; fi
  for e in "${RENAME_MOD[@]}"; do
    IFS=$'\t' read -r from to sim <<< "$e"
    echo "- \`${from}\` → \`${to}\`(similarity ${sim}%)"
  done
  echo ""

  echo "## Soft-deleted(移入 raw/_archive/ → Archive)"
  echo ""
  if [ ${#SOFT_DEL[@]} -eq 0 ]; then echo "None."; fi
  for e in "${SOFT_DEL[@]}"; do
    IFS=$'\t' read -r from to <<< "$e"
    if [ -n "$from" ]; then
      echo "- \`${from}\` → \`${to}\`"
    else
      echo "- \`${to}\`(直接位于 _archive/,无对应删除记录)"
    fi
  done
  echo ""

  echo "## Hard-deleted(硬删除 — 违规,需先处理)"
  echo ""
  if [ ${#HARD_DEL[@]} -eq 0 ]; then echo "None."; fi
  for p in "${HARD_DEL[@]}"; do
    echo "- \`${p}\` ⚠ 请恢复(\`git checkout -- '${p}'\`)或移入 \`raw/_archive/\`,再重跑差分"
  done
  echo ""
} > "$REPORT_MD"

# ─── 5. Raw Diff Report(JSON,机器可读)───
# 固定为一行一条 entry,键序固定;值内的 \ 与 " 会被转义
jesc() {
  local s="${1//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

{
  echo '{'
  echo "  \"generated\": \"${STAMP}\","
  echo "  \"baseline_tag\": \"${BASELINE_TAG}\","
  echo "  \"baseline_commit\": \"${BASELINE_COMMIT}\","
  echo "  \"compared_to\": \"working-tree\","
  echo '  "entries": ['
  LINES=()
  for p in "${ADDED[@]}"; do
    LINES+=("    {\"category\":\"added\",\"path\":\"$(jesc "$p")\"}")
  done
  for p in "${MODIFIED[@]}"; do
    LINES+=("    {\"category\":\"modified\",\"path\":\"$(jesc "$p")\"}")
  done
  for e in "${RENAME_ONLY[@]}"; do
    IFS=$'\t' read -r from to sim <<< "$e"
    LINES+=("    {\"category\":\"rename_only\",\"from\":\"$(jesc "$from")\",\"to\":\"$(jesc "$to")\",\"similarity\":${sim}}")
  done
  for e in "${RENAME_MOD[@]}"; do
    IFS=$'\t' read -r from to sim <<< "$e"
    LINES+=("    {\"category\":\"rename_modified\",\"from\":\"$(jesc "$from")\",\"to\":\"$(jesc "$to")\",\"similarity\":${sim}}")
  done
  for e in "${SOFT_DEL[@]}"; do
    IFS=$'\t' read -r from to <<< "$e"
    LINES+=("    {\"category\":\"soft_deleted\",\"from\":\"$(jesc "$from")\",\"to\":\"$(jesc "$to")\"}")
  done
  for p in "${HARD_DEL[@]}"; do
    LINES+=("    {\"category\":\"hard_deleted\",\"path\":\"$(jesc "$p")\"}")
  done
  n=${#LINES[@]}
  for i in "${!LINES[@]}"; do
    if [ "$i" -lt $((n - 1)) ]; then
      echo "${LINES[$i]},"
    else
      echo "${LINES[$i]}"
    fi
  done
  echo '  ]'
  echo '}'
} > "$REPORT_JSON"

# ─── 6. 汇总 ───
echo "Raw diff complete (baseline ${BASELINE_TAG}@${BASELINE_COMMIT} → working tree):"
echo "  added=${#ADDED[@]} modified=${#MODIFIED[@]} rename-only=${#RENAME_ONLY[@]} rename+modified=${#RENAME_MOD[@]} soft-deleted=${#SOFT_DEL[@]} hard-deleted=${#HARD_DEL[@]}"
echo "  Report: ${REPORT_MD} / ${REPORT_JSON}"
echo "  Next:   ./scripts/ingest-plan.sh ${REPORT_JSON}"

if [ ${#HARD_DEL[@]} -gt 0 ]; then
  echo "ERROR: ${#HARD_DEL[@]} hard-deleted file(s) detected — restore or move to raw/_archive/, then re-run." >&2
  exit 1
fi
