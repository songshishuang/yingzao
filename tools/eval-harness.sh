#!/usr/bin/env bash
# 营造 · 验证门① 真实 before/after 盲评聚合器（确定性部分）
# 读 <run-dir>/scores.json（格式见 references/before-after-protocol.md），算过门判据 + skill_lift/overhaul_lift。
# 角色隔离/盲化/出题由隔离子 Agent 按协议走；本工具只做"确定性聚合 + 棘轮判定"，杜绝门①凭文档观感过关。
# v1.10 D1：① scores.json v2 向后兼容（未知字段忽略、缺字段降级不静默当真）；
#   ② 换序双判模式（条目带 order=AB/BA 时，同评委两序 cand 都优于 orig 才记该评委胜——消位置翻转噪声，YZ-POSBIAS-D1 实测同族单评委约 1/3 翻转、非系统偏）；
#   ③ 长度告警（条目带 cand_len/orig_len 时，cand 远长且胜则提示注水嫌疑）。
# 用法: bash tools/eval-harness.sh <run-dir> [--margin 1.0]
# 退出码: 0 门①通过 / 1 未过门 / 2 用法或数据错误
set -euo pipefail

DIR="${1:-}"; MARGIN="1.0"
shift || true
while [ $# -gt 0 ]; do case "$1" in --margin) MARGIN="$2"; shift 2;; *) shift;; esac; done

[ -n "$DIR" ] || { echo "用法: bash tools/eval-harness.sh <run-dir> [--margin 1.0]"; exit 2; }
S="$DIR/scores.json"
[ -f "$S" ] || { echo "FAIL  缺 $S —— 见 references/before-after-protocol.md 的 scores.json 格式"; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FAIL  需要 jq"; exit 2; }
jq empty "$S" 2>/dev/null || { echo "FAIL  $S 不是合法 JSON"; exit 2; }
# 缺必填字段（prompt/orig/cand）→ 数据错，绝不静默当真
jq -e 'all(.[]; has("prompt") and has("orig") and has("cand"))' "$S" >/dev/null 2>&1 \
  || { echo "FAIL  scores.json 有条目缺 prompt/orig/cand 必填字段 —— 降级不静默，判数据错"; exit 2; }

SWAP=$(jq 'any(.[]; has("order"))' "$S")   # 任一条目带 order → 换序双判模式

if [ "$SWAP" = "true" ]; then
  MODE="换序双判（两序都胜才记胜·消位置噪声）"
  PER=$(jq -c --argjson m "$MARGIN" '
    group_by(.prompt) | map(
      (group_by(.judge) | map({
        orig: ((map(.orig)|add)/length),
        cand: ((map(.cand)|add)/length),
        both_win: (all(.[]; (.cand - .orig) > 0)),
        consistent: ((map((.cand - .orig) > 0) | unique | length) == 1)
      })) as $J |
      { prompt: .[0].prompt, judges: ($J|length),
        orig: (($J|map(.orig)|add)/($J|length)),
        cand: (($J|map(.cand)|add)/($J|length)),
        bare: (if (map(has("bare"))|all) and (length>0) then ((map(.bare)|add)/length) else null end),
        cand_judges: ($J|map(select(.both_win))|length),
        inconsistent: ($J|map(select(.consistent|not))|length) }
      | (.cand - .orig) as $d
      | . + { margin: $d, cand_win: (.cand_judges > (.judges/2)),
              weak: ($d < $m and $d > (-$m)), regress: ($d < -1.0) }
    )' "$S")
else
  MODE="单序（无 order 字段·legacy）"
  PER=$(jq -c --argjson m "$MARGIN" '
    group_by(.prompt) | map(
      { prompt: .[0].prompt, judges: length,
        orig: ((map(.orig)|add)/length),
        cand: ((map(.cand)|add)/length),
        bare: (if (map(has("bare"))|all) and (length>0) then ((map(.bare)|add)/length) else null end),
        inconsistent: 0 }
      | (.cand - .orig) as $d
      | . + { margin: $d, cand_win: ($d > 0), weak: ($d < $m and $d > (-$m)), regress: ($d < -1.0) }
    )' "$S")
fi

n=$(echo "$PER"      | jq 'length')
cwin=$(echo "$PER"   | jq '[.[]|select(.cand_win)]|length')
regress=$(echo "$PER"| jq '[.[]|select(.regress)]|length')
weak=$(echo "$PER"   | jq '[.[]|select(.weak)]|length')
incons=$(echo "$PER" | jq '[.[].inconsistent]|add // 0')
mo=$(echo "$PER"     | jq '([.[].orig]|add)/length')
mc=$(echo "$PER"     | jq '([.[].cand]|add)/length')
hasbare=$(echo "$PER"| jq 'all(.[]; .bare != null)')

echo "── 营造 · 验证门① before/after 聚合 ──  run: $DIR"
echo "模式: $MODE"
printf "%-8s %7s %7s %7s %8s  %s\n" "prompt" "orig" "cand" "Δ" "评委数" "判定"
echo "$PER" | jq -r '.[]|[.prompt,(.orig|.*100|round/100),(.cand|.*100|round/100),(.margin|.*100|round/100),.judges,(if .regress then "回归" elif .cand_win then (if .weak then "微胜(需复测)" else "候选胜" end) else "原版≥候选" end)]|@tsv' \
  | while IFS=$'\t' read -r p o c d j v; do printf "%-8s %7s %7s %7s %8s  %s\n" "$p" "$o" "$c" "$d" "$j" "$v"; done

realized=$(echo "$mc $mo" | awk '{printf "%.2f", $1-$2}')
echo "──"
echo "原版均分 $(printf '%.2f' "$mo")  ｜ 候选均分 $(printf '%.2f' "$mc")  ｜ realized_gain（候选−原版）= $realized"
[ "$SWAP" = "true" ] && [ "$incons" -gt 0 ] && echo "INFO  换序不一致评委 ${incons} 个（其判定按『未达两序一致胜』保守不计胜·消噪生效）"
if [ "$hasbare" = "true" ]; then
  mb=$(echo "$PER" | jq '([.[].bare]|add)/length')
  sl=$(echo "$mo $mb" | awk '{printf "%.2f", $1-$2}')
  ol=$(echo "$mc $mo" | awk '{printf "%.2f", $1-$2}')
  echo "裸基线均分 $(printf '%.2f' "$mb")  ｜ skill_lift（原版−裸）= $sl  ｜ overhaul_lift（候选−原版）= $ol"
  awk -v s="$sl" 'BEGIN{ if (s < 0.3 && s > -0.3) print "提示  skill_lift≈0 → 底模掩盖型：大修难放大，画样应优先「维持/小修」（headroom 低）"; else if (s <= -0.3) print "提示  skill_lift<0 → 有害型：skill 反拖累，优先落架重写或建议弃用"; else print "提示  skill_lift>0 → 技能依赖型：大修高回报区" }'
fi
# M2 长度告警（可选 cand_len/orig_len）：cand 远长且整体胜 → 注水嫌疑
if jq -e 'any(.[]; has("cand_len") and has("orig_len"))' "$S" >/dev/null 2>&1; then
  lr=$(jq '[.[]|select(has("cand_len") and has("orig_len"))] | (map(.cand_len)|add)/(map(.orig_len)|add)' "$S")
  awk -v r="$lr" -v rg="$realized" 'BEGIN{ if (r>1.5 && rg>0) printf "WARN  候选输出平均长 %.2f× 于原版且判胜 → 须人核是否注水赢（评委须长度归一·见 before-after-protocol）\n", r }'
fi

echo "──"
# 门①判据：≥2 题候选胜 + realized_gain>0 + 零回归
pass=$(awk -v cw="$cwin" -v rg="$realized" -v reg="$regress" 'BEGIN{ print (cw>=2 && rg>0 && reg==0) ? 1 : 0 }')
if [ "$weak" -gt 0 ]; then echo "WARN  有 ${weak} 题为微胜（分差<${MARGIN}）→ 按协议须加跑边际复测，仍微弱判未过门"; fi
if [ "$regress" -gt 0 ]; then echo "FAIL  有 ${regress} 题候选明显劣于原版（回归）→ 门①不过，弃该候选（棘轮：分数只升不降）"; fi
if [ "$pass" = "1" ]; then
  echo "✅ 门①通过：${cwin}/${n} 题候选胜、realized_gain=${realized}>0、零回归（模式：${MODE}）"; exit 0
else
  echo "❌ 门①未过：候选胜 ${cwin}/${n}（需≥2）、realized_gain=${realized}（需>0）、回归 ${regress} 题（需0）"; exit 1
fi
