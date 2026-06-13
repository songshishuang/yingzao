#!/usr/bin/env bash
# 营造 · 分层与哨兵确定性测试（v1.4 防静默漂移改造）
# 四组：T1 哨兵报警 / T2 哨兵不误报 / T3 升级保留覆盖 / T4 安装态判据
# 用法: bash yingzao/tests/test-layering.sh   （仓库根运行）
# 退出码: 0 全过 / 1 有失败（可挂 CI）
set -uo pipefail
cd "$(dirname "$0")/../.."   # yingzao/tests/ → 仓库根
ROOT="$(pwd)"
PASS=0; FAIL=0
ok(){ echo "  PASS  $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL  $1"; FAIL=$((FAIL+1)); }

echo "【T1 哨兵报警:核心被改 → self-integrity 应 FAIL】"
T1=$(mktemp -d); cp -R yingzao "$T1/yingzao"
printf '\n# drift test\n' >> "$T1/yingzao/references/scoring.md"
if bash "$T1/yingzao/tools/self-integrity.sh" >/dev/null 2>&1; then no "核心被改却未报警"; else ok "核心被改 → 哨兵 exit 1"; fi
rm -rf "$T1"

echo "【T2 哨兵不误报:仅改 .local → self-integrity 应 PASS】"
T2=$(mktemp -d); cp -R yingzao "$T2/yingzao"
printf '\nL-1. 本地反模式\n' >> "$T2/yingzao/references/anti-patterns.local.md"
if bash "$T2/yingzao/tools/self-integrity.sh" >/dev/null 2>&1; then ok "仅改 .local → 哨兵 exit 0(不误报)"; else no ".local 改动被误判为核心漂移"; fi
rm -rf "$T2"

echo "【T3 升级:.local 积累保留 + 核心乱改被覆盖】"
T3=$(mktemp -d)
bash install.sh --dest "$T3/sk" >/dev/null 2>&1
printf '\nL-9. 使用者积累\n' >> "$T3/sk/yingzao/references/anti-patterns.local.md"
printf '\n# 使用者乱改核心\n' >> "$T3/sk/yingzao/references/scoring.md"
bash install.sh --dest "$T3/sk" >/dev/null 2>&1
grep -q "L-9. 使用者积累" "$T3/sk/yingzao/references/anti-patterns.local.md" && ok ".local 使用者积累被保留" || no ".local 积累丢失"
grep -q "使用者乱改核心" "$T3/sk/yingzao/references/scoring.md" && no "核心乱改未被覆盖(漂移残留)" || ok "核心被主线覆盖(漂移清除)"
rm -rf "$T3"

echo "【T4 安装态判据:装载副本不含 docs/，源仓含 docs/】"
T4=$(mktemp -d); bash install.sh --dest "$T4/sk" >/dev/null 2>&1
[ -d "$T4/sk/yingzao/docs" ] && no "装载副本含 docs/(误判为开发态)" || ok "装载副本无 docs/ → 安装态判据成立"
[ -d "$ROOT/docs" ] && ok "源仓含 docs/ → 开发态判据成立" || no "源仓缺 docs/"
rm -rf "$T4"

echo ""
echo "── test-layering 汇总:PASS $PASS / FAIL $FAIL ──"
[ "$FAIL" -eq 0 ] || exit 1
