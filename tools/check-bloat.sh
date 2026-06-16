#!/usr/bin/env bash
# 营造 · D2 候选冗长度护栏（确定性）
# ρ = 字符比（wc -m，非字节——中文 skill 防 UTF-8 系统性惩罚）= chars(候选) / chars(原版)
# 判据：ρ≤1.15 放行 / 1.15<ρ≤1.5 联动门（须 realized_gain 偿付 Δ/(ρ−1)≥θ）/ ρ>1.5 硬拒重投
# θ 首版=1.0（v1.9 实测 realized 均值仅 +0.23，θ=10 会毙掉所有候选·待 YZ-GUARDRAIL-D2 回填，见 references/guardrails.md）
# 落架模式 --overhaul 豁免 ρ 门（整体重构本就大改）
# 用法: bash tools/check-bloat.sh <原版文件> <候选文件> [--overhaul]
# 退出码: 0 放行(PASS/落架豁免) / 1 联动门(COND·须偿付) / 2 硬拒(FAIL) / 3 用法错
set -euo pipefail
THETA="${THETA:-1.0}"
A="${1:-}"; B="${2:-}"; OVERHAUL=0
[ "${3:-}" = "--overhaul" ] && OVERHAUL=1
{ [ -f "$A" ] && [ -f "$B" ]; } || { echo "用法: bash tools/check-bloat.sh <原版> <候选> [--overhaul]"; exit 3; }

a=$(wc -m <"$A" | tr -d ' '); b=$(wc -m <"$B" | tr -d ' ')
[ "$a" -gt 0 ] || { echo "FAIL  原版字符数为 0"; exit 3; }
rho=$(awk -v a="$a" -v b="$b" 'BEGIN{printf "%.3f", b/a}')

if [ "$OVERHAUL" = "1" ]; then
  echo "PASS  落架模式豁免 ρ 门（ρ=${rho}·原版 ${a}字 候选 ${b}字）"; exit 0
fi
verdict=$(awk -v r="$rho" -v t="$THETA" 'BEGIN{
  if (r<=1.15) print "PASS";
  else if (r<=1.5) printf "COND %.2f", (r-1)*t;   # 需偿付的 realized_gain 下限
  else print "FAIL";
}')
case "$verdict" in
  PASS*) echo "PASS  ρ=${rho}≤1.15 放行（原版 ${a}字 候选 ${b}字）"; exit 0;;
  COND*) need=$(echo "$verdict" | awk '{print $2}')
         echo "COND  1.15<ρ=${rho}≤1.5 → 须 realized_gain ≥ Δ/(ρ−1)·θ = ${need} 分（0-10 标度·θ=${THETA}）方过冗长门（见 guardrails.md）"; exit 1;;
  FAIL*) echo "FAIL  ρ=${rho}>1.5 硬拒重投（原版 ${a}字 候选 ${b}字·膨胀过度=需偿付增益的负债·落架可加 --overhaul 豁免）"; exit 2;;
esac
