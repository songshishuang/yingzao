#!/usr/bin/env bash
# 营造 · HTML 报告渲染引擎自测（CI 用）—— 锁死 tools/render-report.py 的产物契约：
# 自包含(零外链) / SVG 雷达 / 核心结论 / 深浅色 / kind 分流 / 坏数据退出码 / 缺字段优雅跳过。
# 退出码语义（见 render-report.py 头注）：0 渲染成功 / 2 用法或数据错。
# 无 python3 → 整体 SKIP（降级只出 markdown 是设计·不算失败）。
set -uo pipefail

RENDER="$(cd "$(dirname "$0")/.." && pwd)/tools/render-report.py"
pass=0; fail=0
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

if ! command -v python3 >/dev/null 2>&1; then
  echo "── render-report 自测：SKIP（无 python3·降级只出 markdown 是设计）──"
  exit 0
fi

ok()  { echo "PASS  $1"; pass=$((pass+1)); }
bad() { echo "FAIL  $1"; fail=$((fail+1)); }

cat > "$TMP/full.json" <<'JSON'
{"kind":"full","meta":{"skill":"t","date":"2026-06-17","form":"方法论型","role":"PM"},
"human":{"score_now":94,"items":[{"problem":"p","why":"w","after":"a"}]},
"verdict":{"score_before":94,"score_after":94,"niche":"n","signature":"s","next":"x"},
"scores":[{"abbr":"触发","score":7,"full":7},{"abbr":"工作流","score":12,"full":12},{"abbr":"失败模式","score":11,"full":12},{"abbr":"检查点","score":6,"full":6},{"abbr":"具体性","score":16,"full":17},{"abbr":"资源","score":4,"full":4},{"abbr":"架构","score":11,"full":12},{"abbr":"安全","score":6,"full":7},{"abbr":"实测","score":21,"full":23}],
"headroom":{"type":"撞顶","bars":[{"label":"装载版","pass":18,"total":20},{"label":"裸基线","pass":0,"total":20}]},
"gaps":[{"level":"P0","title":"g","V":"v","A":"a","K":"k","adopted":true}],
"rounds":[{"variable":"r1","result":"ok","verdict":"采纳","pass":true},{"variable":"cx","result":"无互补","verdict":"未触发","pass":null}],
"sections":{"xiangdi":"xd","plan":["p1","p2"]}}
JSON

cat > "$TMP/quick.json" <<'JSON'
{"kind":"quick","meta":{"skill":"t","date":"2026-06-17","role":"运营"},
"human":{"score_now":70,"items":[{"problem":"p","why":"w","after":"a"}]},
"scores":[{"abbr":"触发","score":5,"full":7},{"abbr":"工作流","score":8,"full":12},{"abbr":"失败模式","score":6,"full":12}],
"gaps":[{"level":"P0","title":"g"}],
"sections":{"sanwen":"三问","advice":"建议"}}
JSON

echo '{"kind":"full","meta":{' > "$TMP/bad.json"
echo '{"kind":"full","meta":{"skill":"m"}}' > "$TMP/min.json"

echo "── HTML 报告渲染引擎自测 ──"

# 1. full 渲染成功 exit 0
python3 "$RENDER" "$TMP/full.json" "$TMP/full.html" >/dev/null 2>&1
[ $? -eq 0 ] && ok "full → exit 0（渲染成功）" || bad "full → 期望 exit 0"

# 2. 自包含：零外部引用
n=$(grep -cE 'https?://|<script|<link |cdn|src=' "$TMP/full.html" 2>/dev/null || true)
[ "$n" -eq 0 ] && ok "full 自包含（零外部引用·断网可开）" || bad "full 含 $n 处外部引用（应 0·破自包含）"

# 3. SVG 雷达：网格4+数据1=5 个 polygon
n=$(grep -o '<polygon' "$TMP/full.html" | wc -l | tr -d ' ')
[ "$n" -eq 5 ] && ok "full SVG 雷达 5 polygon（4 网格+1 数据）" || bad "full SVG polygon=${n}（期望 5）"

# 4. 核心结论 + 深浅色自适应
grep -q '核心结论' "$TMP/full.html" && grep -q 'prefers-color-scheme:dark' "$TMP/full.html" \
  && ok "full 含核心结论区块 + 深浅色自适应" || bad "full 缺核心结论或深浅色"

# 5. full 含落成匾/headroom/验证门时间线
grep -q '落成匾' "$TMP/full.html" && grep -q 'headroom 判定' "$TMP/full.html" && grep -q 'timeline' "$TMP/full.html" \
  && ok "full 含落成匾+headroom+验证门时间线" || bad "full 缺核心区块"

# 6. quick 分流：含相地三问、不含 full 专属区块
python3 "$RENDER" "$TMP/quick.json" "$TMP/quick.html" >/dev/null 2>&1
if [ $? -eq 0 ] && grep -q '相地三问' "$TMP/quick.html" && ! grep -q '落成匾' "$TMP/quick.html" && ! grep -q 'headroom 判定' "$TMP/quick.html"; then
  ok "quick 分流正确（含三问·无落成匾/headroom）"
else
  bad "quick 分流错误（应含三问、无 full 专属区块）"
fi

# 7. 坏数据 → exit 2（杜绝坏 JSON 蒙混出报告）
python3 "$RENDER" "$TMP/bad.json" "$TMP/bad.html" >/dev/null 2>&1
[ $? -eq 2 ] && ok "非法 JSON → exit 2（数据错）" || bad "非法 JSON → 期望 exit 2"

# 8. 最小数据（仅 kind+meta）→ exit 0 优雅跳过空区块
python3 "$RENDER" "$TMP/min.json" "$TMP/min.html" >/dev/null 2>&1
[ $? -eq 0 ] && grep -q '<!DOCTYPE html>' "$TMP/min.html" && ok "最小数据 → exit 0（空区块优雅跳过）" || bad "最小数据渲染失败"

echo "── PASS $pass / FAIL $fail ──"
[ "$fail" -eq 0 ]
