#!/usr/bin/env bash
# 营造 · 报告数据契约校验（v1.7 竞品链大修引入 · 让「机器可校验」落到确定性脚本）
# 校验大修报告 §2 启示清单 的启示ID 全集 == §5a 对标启示转化表 的启示ID 全集。
#   不相等 = 对标启示断流(§2有§5a无) 或 凭空(§5a有§2无) → exit 1。
# 用法: validate-report-contract.sh <report.md>
# 退出: 0 一致 / 1 不一致 / 2 用法错
# 约定(报告须遵守): 启示ID 形如 E1/E2…(行首列); §2 段标题含「启示清单」; §5a 段标题含「对标启示转化表」;
#                   §5a 段止于「总差距清单」或下一个「## 」或「---」。勘验项走 §5b、不在本校验内。
set -uo pipefail
R="${1:-}"
[ -n "$R" ] && [ -f "$R" ] || { echo "用法: $(basename "$0") <report.md>" >&2; exit 2; }

# 提取某段(起锚→止锚之间)表格行内的启示ID(E\d+)
seg_ids() { # $1=起锚正则 $2=止锚正则
  awk -v s="$1" -v e="$2" '
    $0 ~ s {seg=1; next}
    seg && $0 ~ e {seg=0}
    seg && /^[[:space:]]*\|/ {
      if (match($0, /\|[[:space:]]*E[0-9]+[[:space:]]*\|/)) {
        t=substr($0,RSTART,RLENGTH); gsub(/[|[:space:]]/,"",t); print t
      }
    }
  ' "$R" | sort -u | grep . || true
}

S2="$(seg_ids '启示清单' '对标启示转化表|总差距清单|^## ')"
S5="$(seg_ids '对标启示转化表' '总差距清单|^## |^---')"

n2=$(printf '%s\n' "$S2" | grep -c . || true)
n5=$(printf '%s\n' "$S5" | grep -c . || true)
miss=$(comm -23 <(printf '%s\n' "$S2") <(printf '%s\n' "$S5") | grep . || true)
extra=$(comm -13 <(printf '%s\n' "$S2") <(printf '%s\n' "$S5") | grep . || true)

echo "── 报告数据契约校验 ──  §2 启示清单: ${n2} 条 ｜ §5a 转化表: ${n5} 条"
if [ "$n2" -gt 0 ] && [ -z "$miss" ] && [ -z "$extra" ]; then
  echo "PASS  数据契约一致: ${n2} 条对标启示全部有转化（0 断流）"
  exit 0
fi
[ "$n2" -eq 0 ] && echo "FAIL  §2 启示清单为空或未识别（检查启示ID格式 E\\d+ 与段标题「启示清单」）"
[ -n "$miss" ]  && { echo "FAIL  断流(§2有§5a无):"; printf '  %s\n' $miss; }
[ -n "$extra" ] && { echo "FAIL  凭空(§5a有§2无):"; printf '  %s\n' $extra; }
echo "结论: 数据契约不一致——对标启示未做到 0 断流，不得过门"
exit 1
