#!/usr/bin/env bash
# 营造 · 发布一致性门禁（真相源 = VERSION 文件）
# 校验：版本号四处一致（VERSION / README badge / marketplace / SKILL.md Changelog）
#       + README 内部战绩自洽（副标题分数序列 == 战绩表后分集合）
# 用法: bash tools/check-release.sh   （仓库根运行）
# 退出码: 0 全过 / 1 有不一致（CI 门禁用）
set -euo pipefail
cd "$(dirname "$0")/.."

FAIL=0
ok()   { echo "PASS  $1"; }
bad()  { echo "FAIL  $1"; FAIL=1; }

V=$(tr -d ' \n' < VERSION)
echo "── 真相源 VERSION = $V ──"

# 1. README badge
if grep -q "version-$V-" README.md; then ok "README badge = $V"; else bad "README badge ≠ $V"; fi
# 2. README 头部声明行（**vX.Y** 或 **vX.Y.Z**）
if grep -qE "\*\*v$V\*\*|\*\*v${V%.*}\*\*" README.md; then ok "README 头部版本声明含 $V 系"; else bad "README 头部版本声明缺 $V"; fi
# 3. marketplace.json
if grep -q "\"version\": \"$V\"" .claude-plugin/marketplace.json; then ok "marketplace.json = $V"; else bad "marketplace.json ≠ $V"; fi
# 4. SKILL.md Changelog 含该版本（接受 vX.Y 或 vX.Y.Z，按 major.minor 匹配）
VMM=${V%.*}
if grep -qE "v($V|$VMM)\b" SKILL.md; then ok "SKILL.md Changelog 含 v$VMM 系"; else bad "SKILL.md Changelog 缺 v$VMM"; fi

# 5. README 内部战绩自洽：战绩用「前→后」箭头表达，只取「整数前分→后分」形态（排除 6→9.5 这类实测子分）
#    口径：前分为整数或 NN.N、后分允许 ~ 前缀；副标题分数序列集合 == 战绩表后分集合
sub=$(grep -oE '[0-9]{2,}(\.[0-9])?→[~]?[0-9]{2,}(\.[0-9])?' README.md | sed -E 's/.*→[~]?//' | sort -u | tr '\n' ' ')
tbl=$(grep -oE '→ \*\*[~]?[0-9]{2,}(\.[0-9])?\*\*' README.md | sed -E 's/→ \*\*[~]?//; s/\*\*//' | sort -u | tr '\n' ' ')
if [ -n "$sub" ] && [ "$sub" = "$tbl" ]; then ok "README 战绩自洽（副标题 = 战绩表后分: ${sub}）"
else bad "README 战绩不自洽 — 副标题[$sub] vs 战绩表[$tbl]"; fi

# 5b. README 平均分自洽：所有「平均 +N 分」文字必须同值（堵手写平均分漂移——确定性脚本此前的盲区）
avg_uniq=$(grep -oE '平均 \+[0-9]+(\.[0-9])? 分' README.md | sort -u || true)
avg_n=$(printf '%s\n' "$avg_uniq" | sed '/^$/d' | wc -l | tr -d ' ')
if [ "$avg_n" -le 1 ]; then ok "README 平均分自洽（$(printf '%s' "$avg_uniq" | tr '\n' ' ')）"
else bad "README 平均分不一致 — $(printf '%s' "$avg_uniq" | tr '\n' ' / ')"; fi

# 6. baseline.lock 是最新的（核心改动后须 gen-baseline 重新生成，否则完整性哨兵基线过期）
if bash tools/gen-baseline.sh --check >/dev/null 2>&1; then ok "baseline.lock 是最新的（核心完整性基线）"; else bad "baseline.lock 已过期——运行 bash tools/gen-baseline.sh 重新生成"; fi

echo "──"
if [ "$FAIL" -eq 0 ]; then echo "✅ 发布一致性全过"; else echo "❌ 存在不一致，发布前修复"; fi
exit $FAIL
