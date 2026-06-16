#!/usr/bin/env bash
# 营造 · 验证门① 真实 before/after 盲评聚合器（确定性部分）
# 读 <run-dir>/scores.json（格式见 references/before-after-protocol.md），算过门判据 + skill_lift/overhaul_lift。
# 角色隔离/盲化/出题由隔离子 Agent 按协议走；本工具只做"确定性聚合 + 棘轮判定"，杜绝门①凭文档观感过关。
# v1.10 D1：scores.json v2（向后兼容·缺字段降级）+ 换序双判(order=AB/BA·两序都胜才记胜·消位置噪声) + 长度告警(cand_len/orig_len)
# v1.10 D3：逐 run 点校准(pred_gain→calib_err=realized−pred·负=高估)
# v1.10 D2：held-out(set=="holdout" 不参与门①·只读报告)
# v1.10 D7：确定性验证器证据层(det==true·pass_orig/pass_cand∈{0,1}·与盲评互补·按形态分流·det_gate=Σpass_cand−Σpass_orig≥1 且零回归)
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
# 必填字段：盲评项需 prompt/orig/cand；det 项需 prompt/pass_orig/pass_cand —— 缺则数据错、绝不静默当真
jq -e 'all(.[]; if (.det==true) then (has("prompt") and has("pass_orig") and has("pass_cand")) else (has("prompt") and has("orig") and has("cand")) end)' "$S" >/dev/null 2>&1 \
  || { echo "FAIL  字段缺失（盲评项需 prompt/orig/cand·det 项需 prompt/pass_orig/pass_cand）—— 降级不静默，判数据错"; exit 2; }

BLIND=$(jq -c '[.[]|select(.det != true)]' "$S")          # 盲评项（非 det）
nblind=$(echo "$BLIND" | jq 'length')
DET=$(jq -c '[.[]|select(.det == true)]' "$S")            # 确定性验证器项
ndet=$(echo "$DET" | jq 'length')

echo "── 营造 · 验证门① before/after 聚合 ──  run: $DIR"
blind_pass="NA"; realized="NA"
if [ "$nblind" -gt 0 ]; then
  SWAP=$(echo "$BLIND" | jq 'any(.[]; has("order"))')
  if [ "$SWAP" = "true" ]; then
    MODE="换序双判（两序都胜才记胜·消位置噪声）"
    PER=$(echo "$BLIND" | jq -c --argjson m "$MARGIN" '
      [.[]|select((.set//"gate")!="holdout")] | group_by(.prompt) | map(
        (group_by(.judge) | map({ orig: ((map(.orig)|add)/length), cand: ((map(.cand)|add)/length),
          both_win: (all(.[]; (.cand - .orig) > 0)), consistent: ((map((.cand - .orig) > 0)|unique|length)==1) })) as $J |
        { prompt: .[0].prompt, judges: ($J|length), orig: (($J|map(.orig)|add)/($J|length)), cand: (($J|map(.cand)|add)/($J|length)),
          bare: (if (map(has("bare"))|all) and (length>0) then ((map(.bare)|add)/length) else null end),
          cand_judges: ($J|map(select(.both_win))|length), inconsistent: ($J|map(select(.consistent|not))|length) }
        | (.cand - .orig) as $d | . + { margin: $d, cand_win: (.cand_judges > (.judges/2)), weak: ($d < $m and $d > (-$m)), regress: ($d < -1.0) })')
  else
    MODE="单序（无 order 字段·legacy）"
    PER=$(echo "$BLIND" | jq -c --argjson m "$MARGIN" '
      [.[]|select((.set//"gate")!="holdout")] | group_by(.prompt) | map(
        { prompt: .[0].prompt, judges: length, orig: ((map(.orig)|add)/length), cand: ((map(.cand)|add)/length),
          bare: (if (map(has("bare"))|all) and (length>0) then ((map(.bare)|add)/length) else null end), inconsistent: 0 }
        | (.cand - .orig) as $d | . + { margin: $d, cand_win: ($d > 0), weak: ($d < $m and $d > (-$m)), regress: ($d < -1.0) })')
  fi
  n=$(echo "$PER" | jq 'length')
  if [ "$n" -gt 0 ]; then
    cwin=$(echo "$PER"|jq '[.[]|select(.cand_win)]|length'); regress=$(echo "$PER"|jq '[.[]|select(.regress)]|length')
    weak=$(echo "$PER"|jq '[.[]|select(.weak)]|length'); incons=$(echo "$PER"|jq '[.[].inconsistent]|add // 0')
    mo=$(echo "$PER"|jq '([.[].orig]|add)/length'); mc=$(echo "$PER"|jq '([.[].cand]|add)/length')
    hasbare=$(echo "$PER"|jq 'all(.[]; .bare != null)')
    echo "盲评模式: $MODE"
    printf "%-8s %7s %7s %7s %8s  %s\n" "prompt" "orig" "cand" "Δ" "评委数" "判定"
    echo "$PER" | jq -r '.[]|[.prompt,(.orig|.*100|round/100),(.cand|.*100|round/100),(.margin|.*100|round/100),.judges,(if .regress then "回归" elif .cand_win then (if .weak then "微胜(需复测)" else "候选胜" end) else "原版≥候选" end)]|@tsv' \
      | while IFS=$'\t' read -r p o c d j v; do printf "%-8s %7s %7s %7s %8s  %s\n" "$p" "$o" "$c" "$d" "$j" "$v"; done
    realized=$(echo "$mc $mo" | awk '{printf "%.2f", $1-$2}')
    echo "原版均分 $(printf '%.2f' "$mo")  ｜ 候选均分 $(printf '%.2f' "$mc")  ｜ realized_gain（候选−原版）= $realized"
    pred=$(jq -r '[.[].pred_gain]|map(select(.!=null))|if length>0 then .[0] else "null" end' "$S")
    if [ "$pred" != "null" ]; then ce=$(awk -v y="$realized" -v p="$pred" 'BEGIN{printf "%.2f",y-p}'); echo "── 预测校准（点）── 预测提分 ${pred} vs 实测 ${realized} ｜ 有向误差(实测−预测)=${ce}（负=本轮高估·见 scoring 硬规则5）"; fi
    HOLD=$(jq -c '[.[]|select(.set=="holdout")]' "$S"); nhold=$(echo "$HOLD"|jq 'length')
    if [ "$nhold" -gt 0 ]; then hgd=$(echo "$HOLD"|jq '((map(.cand)|add)/length)-((map(.orig)|add)/length)'); echo "── held-out 泛化（只读·不参与过门·落成匾分以此为准）── ${nhold} 条、cand−orig=$(printf '%.2f' "$hgd")（过拟合告警·N<4 仅哨兵·见 guardrails.md）"; fi
    if [ "$hasbare" = "true" ]; then mb=$(echo "$PER"|jq '([.[].bare]|add)/length'); sl=$(echo "$mo $mb"|awk '{printf "%.2f",$1-$2}'); ol=$(echo "$mc $mo"|awk '{printf "%.2f",$1-$2}')
      echo "裸基线均分 $(printf '%.2f' "$mb")  ｜ skill_lift（原版−裸）= $sl  ｜ overhaul_lift（候选−原版）= $ol"
      awk -v s="$sl" 'BEGIN{ if(s<0.3&&s>-0.3)print "提示  skill_lift≈0 → 底模掩盖型：大修难放大，画样应优先「维持/小修」"; else if(s<=-0.3)print "提示  skill_lift<0 → 有害型：skill 反拖累，优先落架/弃用"; else print "提示  skill_lift>0 → 技能依赖型：大修高回报区" }'; fi
    if jq -e 'any(.[]; has("cand_len") and has("orig_len"))' "$S" >/dev/null 2>&1; then lr=$(jq '[.[]|select(has("cand_len") and has("orig_len"))]|(map(.cand_len)|add)/(map(.orig_len)|add)' "$S"); awk -v r="$lr" -v rg="$realized" 'BEGIN{ if(r>1.5&&rg>0)printf "WARN  候选输出平均长 %.2f× 且判胜 → 须人核是否注水赢\n",r }'; fi
    [ "$weak" -gt 0 ] && echo "WARN  有 ${weak} 题微胜（分差<${MARGIN}）→ 须加跑边际复测，仍微弱判未过门"
    [ "$regress" -gt 0 ] && echo "FAIL  有 ${regress} 题候选明显劣于原版（回归）→ 门①不过、棘轮弃候选"
    blind_pass=$(awk -v cw="$cwin" -v rg="$realized" -v reg="$regress" 'BEGIN{print (cw>=2 && rg>0 && reg==0)?1:0}')
  else
    echo "盲评：holdout 过滤后无 gate 项可判"; blind_pass="NA"
  fi
fi

# D7 确定性验证器门
det_pass="NA"
if [ "$ndet" -gt 0 ]; then
  po=$(echo "$DET"|jq '[.[].pass_orig]|add'); pc=$(echo "$DET"|jq '[.[].pass_cand]|add')
  det_lift=$((pc - po)); reg_det=$(echo "$DET"|jq '[.[]|select(.pass_cand==0 and .pass_orig==1)]|length')
  echo "── 确定性验证器门（det·程序判对错·零评分方差）── 题数 ${ndet} ｜ pass 原版 ${po} / 候选 ${pc} ｜ det_lift=${det_lift} ｜ 回归题 ${reg_det}"
  hasdbare=$(echo "$DET"|jq 'all(.[]; .pass_bare != null)')
  [ "$hasdbare" = "true" ] && { pb=$(echo "$DET"|jq '[.[].pass_bare]|add'); echo "   det_skill_lift（原版−裸 pass）= $((po - pb))（headroom 客观锚）"; }
  det_pass=$(awk -v dl="$det_lift" -v rd="$reg_det" 'BEGIN{print (dl>=1 && rd==0)?1:0}')
  [ "$det_pass" = "0" ] && echo "   det 门未过：det_lift=${det_lift}（需≥1）、回归 ${reg_det} 题（需0）"
fi

echo "──"
# 合并裁决：有盲评则盲评须过；有 det 则 det 须过；两者皆无=数据错
if [ "$blind_pass" = "NA" ] && [ "$det_pass" = "NA" ]; then echo "FAIL  既无盲评项也无 det 项可判"; exit 2; fi
overall=1
[ "$blind_pass" = "0" ] && overall=0
[ "$det_pass" = "0" ] && overall=0
if [ "$overall" = "1" ]; then
  echo "✅ 门①通过（盲评:${blind_pass} ｜ 确定性:${det_pass}）"; exit 0
else
  echo "❌ 门①未过（盲评:${blind_pass} ｜ 确定性:${det_pass}）"; exit 1
fi
