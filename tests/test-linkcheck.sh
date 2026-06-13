#!/usr/bin/env bash
# 营造 · 内链检查 monorepo 豁免测试（P0-1 防回归 · Y-011 dogfood 反向发现）
# 验证 inspect-skill.sh 第 5 项内链检查：
#   L1 不对 ../ 上级相对路径（monorepo 共享资源）误报死链
#   L2 仍检出 skill 目录内的真死链（不因豁免而漏检）
# 用法: bash tests/test-linkcheck.sh   （仓库根运行）
# 退出码: 0 全过 / 1 有失败（可挂 CI）
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
PASS=0; FAIL=0
ok(){ echo "  PASS  $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL  $1"; FAIL=$((FAIL+1)); }

SK="$ROOT/tests/fixtures/monorepo-link-demo/skills/sample-skill"
OUT=$(bash "$ROOT/tools/inspect-skill.sh" "$SK" --target internal 2>&1 || true)

echo "【L1 上级相对路径 ../../tools/REGISTRY.md 不得误报死链】"
if echo "$OUT" | grep -q "内链文件不存在: tools/REGISTRY.md"; then
  no "误报：../../tools/REGISTRY.md 被当成 skill 目录内死链"
else
  ok "未对上级共享资源误报"
fi

echo "【L2 skill 目录内真死链 references/does-not-exist.md 仍须检出】"
if echo "$OUT" | grep -q "内链文件不存在: references/does-not-exist.md"; then
  ok "真死链仍被检出（豁免未误伤真检查）"
else
  no "漏检：skill 目录内真死链未报"
fi

echo ""
echo "── test-linkcheck 汇总: PASS $PASS / FAIL $FAIL ──"
[ "$FAIL" -eq 0 ] || exit 1
