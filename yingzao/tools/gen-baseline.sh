#!/usr/bin/env bash
# 营造 · 生成核心完整性基线 baseline.lock（仅开发态发版时运行）
# 监控主线「行为核心」——改了会改变营造行为的文件；不含 *.local.md / tests/ / baseline.lock 自身。
# 版本号 embed 进 lock 头部，使安装态（无仓库根 VERSION）也能报告基线对应版本。
# 用法: bash yingzao/tools/gen-baseline.sh   （仓库根运行）
set -euo pipefail
cd "$(dirname "$0")/.."   # → skill 根 yingzao/

MODE="write"; [ "${1:-}" = "--check" ] && MODE="check"   # --check：只校验 lock 是否最新，不写盘

sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
VER="$(tr -d ' \n' < ../VERSION 2>/dev/null || echo '?')"
LOCK="tools/baseline.lock"
TMP="$(mktemp)"

echo "# yingzao 核心完整性基线 · version: $VER · 由 gen-baseline.sh 生成（开发态发版）" > "$TMP"
{
  echo "SKILL.md"
  find references -maxdepth 1 -name '*.md' ! -name '*.local.md'
  find templates -maxdepth 1 -name '*.md'
  find tools -maxdepth 1 -name '*.sh'
} | sort -u | while read -r f; do
  [ -f "$f" ] && echo "$(sha "$f")  $f"
done >> "$TMP"

if [ "$MODE" = "check" ]; then
  if [ ! -f "$LOCK" ]; then echo "✘ baseline.lock 不存在——请运行 gen-baseline.sh 生成"; rm -f "$TMP"; exit 1; fi
  if diff -q "$LOCK" "$TMP" >/dev/null 2>&1; then
    echo "✓ baseline.lock 是最新的（version $VER，$(grep -cE '^[0-9a-f]' "$LOCK") 个核心文件）"; rm -f "$TMP"; exit 0
  else
    echo "✘ baseline.lock 已过期——核心改动后须运行 gen-baseline.sh 重新生成。差异："; diff "$LOCK" "$TMP" || true; rm -f "$TMP"; exit 1
  fi
fi
mv "$TMP" "$LOCK"
echo "✓ 已生成 $LOCK（version $VER，$(grep -cE '^[0-9a-f]' "$LOCK") 个核心文件）"
