#!/usr/bin/env bash
# 营造 · eval-harness 行为夹具自测（CI 用）—— 4 类小而硬的样例锁死 tools/eval-harness.sh 的退出码语义，
# 防验证门①聚合器回归。退出码语义（见 tools/eval-harness.sh 头注）：0 门①通过 / 1 未过门 / 2 用法或数据错。
set -uo pipefail

HARNESS="$(cd "$(dirname "$0")/.." && pwd)/tools/eval-harness.sh"
FIX="$(cd "$(dirname "$0")" && pwd)/fixtures/eval-harness"
pass=0; fail=0

check() {  # $1=夹具目录  $2=期望退出码  $3=说明
  bash "$HARNESS" "$FIX/$1" >/dev/null 2>&1; local got=$?
  if [ "$got" -eq "$2" ]; then
    echo "PASS  $1 → exit ${got}（${3}）"; pass=$((pass+1))
  else
    echo "FAIL  $1 → 期望 exit $2 实得 ${got}（${3}）"; fail=$((fail+1))
  fi
}

echo "── eval-harness 行为夹具自测 ──"
check candidate-wins 0 "≥2 题明显胜 + realized_gain>0 + 零回归 → 门①通过"
check regression     1 "有题候选明显劣于原版（回归 Δ<-1）→ 门①不过、棘轮弃候选"
check weak-gain      1 "弱增益 + 单点退化、realized_gain≤0、不足 2 题明显胜 → 未过门"
check invalid        2 "scores.json 非法 JSON → 数据错（杜绝凭坏数据蒙混过门）"
check v2-compat          0 "v2 额外字段(set/weight)被容忍 + 候选胜 → 门①通过（向后兼容）"
check swap-consistent-win 0 "换序双判：两序都 cand>orig → 计胜 → 门①通过"
check swap-disagree       1 "换序双判：两序矛盾 → 不计胜（消位置噪声·单序会误判胜）→ 未过门"
check calib               0 "含 pred_gain → 输出逐 run 点对账校准行（D3·向后兼容·退出码不变）"
echo "── PASS $pass / FAIL $fail ──"

[ "$fail" -eq 0 ]
