#!/usr/bin/env bash
# 营造 · 核心完整性哨兵（开工自检：主线核心是否偏离官方基线）
# 比对主线行为核心 hash vs tools/baseline.lock。防 drift（无意漂移），不阻断运行、只如实告知。
# 不防铁了心连 baseline.lock 一起改的 fork（那是自愿放弃官方身份）。
# 用法: bash tools/self-integrity.sh
# 退出码: 0 完整 / 1 偏离或基线缺失
set -euo pipefail
cd "$(dirname "$0")/.."   # → 仓库根（扁平化后 skill 即仓库根）

LOCK="tools/baseline.lock"
sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }

if [ ! -f "$LOCK" ]; then
  echo "⚠️  基线缺失（${LOCK}）——无法校验核心完整性，请开发态运行 gen-baseline.sh 生成。"
  exit 1
fi
VER=$(grep -m1 'version:' "$LOCK" | sed -E 's/.*version: *([^ ·]+).*/\1/')
[ -z "$VER" ] && VER="?"

DRIFT=0
while read -r want f; do
  case "$want" in '#'*|'') continue ;; esac   # 跳过注释/空行
  [ -z "$f" ] && continue
  if [ ! -f "$f" ]; then echo "⚠️  核心文件缺失: $f"; DRIFT=1; continue; fi
  got="$(sha "$f")"
  [ "$got" != "$want" ] && { echo "⚠️  核心文件被改动: ${f}（偏离官方 v${VER}）"; DRIFT=1; }
done < "$LOCK"

LOCAL_N=$(find references -maxdepth 1 -name '*.local.md' 2>/dev/null | wc -l | tr -d ' ')
if [ "$DRIFT" -eq 0 ]; then
  echo "✅ 核心 = 官方 v${VER}（完整）；本地扩展层 $LOCAL_N 个文件"
  exit 0
else
  echo "—— 核心已偏离官方 v${VER}：非主线行为，实测分 / 对标结论可能不可复现。"
  echo "   建议恢复主线（重装）或显式 fork（自愿放弃官方身份）。哨兵不阻断运行，只如实告知。"
  exit 1
fi
