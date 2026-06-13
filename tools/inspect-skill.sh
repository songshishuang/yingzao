#!/usr/bin/env bash
# 营造 · 规则预检（查勘第 2 步的零成本预过滤层）
# 双段式：基础段（团队复用就绪，恒定计入）+ 传播段（开源发布就绪，按发布目标定级）
# 用法: inspect-skill.sh <skill-dir> [--target internal|opensource]
#   <skill-dir> 为含 SKILL.md 的目录（单文件 skill 同样适用）
# 输出: 每条 PASS/WARN/FAIL/INFO + 严重度（必须改/应该改/最佳实践）；FAIL>0 时 exit 1
# 设计依据: 源仓库设计文档 §5.1（github.com/songshishuang/yingzao；设计草稿本地归档，不随仓发行）
# 注: 术语一致性的语义深检由 LLM 勘验承担；本脚本负责确定性可判项（含占位符残留扫描）。
set -euo pipefail

TARGET_MODE="internal"
SKILL_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET_MODE="${2:-internal}"; shift 2 ;;
    -h|--help)
      sed -n '2,9p' "$0"; exit 0 ;;
    *) SKILL_DIR="$1"; shift ;;
  esac
done

if [ -z "$SKILL_DIR" ] || [ ! -d "$SKILL_DIR" ]; then
  echo "用法: $(basename "$0") <skill-dir> [--target internal|opensource]" >&2
  exit 2
fi
case "$TARGET_MODE" in internal|opensource) ;; *) echo "✘ --target 只接受 internal|opensource" >&2; exit 2 ;; esac

SKILL_DIR="$(cd "$SKILL_DIR" && pwd)"
SKILL_MD="$SKILL_DIR/SKILL.md"
PASS_N=0; WARN_N=0; FAIL_N=0; INFO_N=0

pass() { echo "PASS  $1"; PASS_N=$((PASS_N+1)); }
warn() { echo "WARN  [应该改] $1"; WARN_N=$((WARN_N+1)); }
fail() { echo "FAIL  [必须改] $1"; FAIL_N=$((FAIL_N+1)); }
info() { echo "INFO  [最佳实践·开源时需补] $1"; INFO_N=$((INFO_N+1)); }
# 传播段定级：internal -> info；opensource -> warn/fail
prop_gap() { # $1=严重(fail|warn 当 opensource 时)  $2=消息
  if [ "$TARGET_MODE" = "opensource" ]; then
    if [ "$1" = "fail" ]; then fail "$2"; else warn "$2"; fi
  else
    info "$2"
  fi
}

echo "── 营造 · 规则预检 ──  目标: $SKILL_DIR"
echo "── 发布目标: $TARGET_MODE"
echo ""
echo "【基础段 · 团队复用就绪度】"

# 1. frontmatter 完整性与触发词
if [ ! -f "$SKILL_MD" ]; then
  fail "SKILL.md 不存在于 $SKILL_DIR"
else
  pass "SKILL.md 存在"
  FM="$(sed -n '/^---$/,/^---$/p' "$SKILL_MD" | head -60)"
  if printf '%s' "$FM" | grep -q '^name:'; then
    pass "frontmatter 含 name"
  else
    fail "frontmatter 缺 name 字段"
  fi
  if printf '%s' "$FM" | grep -q '^description:'; then
    DESC_LEN=$(printf '%s' "$FM" | sed -n '/^description:/,/^[a-z_]*:/p' | wc -c | tr -d ' ')
    if [ "$DESC_LEN" -ge 120 ]; then
      pass "frontmatter 含 description 且有触发语料（${DESC_LEN}c）"
    else
      warn "description 过短（${DESC_LEN}c）——补使用者真实会说的触发词与负触发"
    fi
  else
    fail "frontmatter 缺 description 字段"
  fi

  # 2. 行数预算
  LINES=$(wc -l < "$SKILL_MD" | tr -d ' ')
  if [ "$LINES" -le 500 ]; then
    pass "SKILL.md 行数 ${LINES} ≤ 500"
  else
    warn "SKILL.md ${LINES} 行超 500 预算——建议拆分 references/（渐进披露）"
  fi

  # 3. 引用链深度（references 内文件不应再引用 references/ 形成两层）
  DEEP_REF=0
  if [ -d "$SKILL_DIR/references" ]; then
    for rf in "$SKILL_DIR"/references/*.md; do
      [ -f "$rf" ] || continue
      if grep -q 'references/' "$rf" 2>/dev/null; then DEEP_REF=1; fi
    done
  fi
  if [ "$DEEP_REF" -eq 0 ]; then
    pass "引用链一层深（references 内无二级引用）"
  else
    warn "references 内仍引用 references/——引用链超一层，阅读路径变深"
  fi

  # 4. 代码栅栏闭合（``` 总数应为偶数）
  FENCE=$(grep -c '^```' "$SKILL_MD" 2>/dev/null) || FENCE=0
  if [ $((FENCE % 2)) -eq 0 ]; then
    pass "代码栅栏闭合（\`\`\` × ${FENCE}）"
  else
    fail "代码栅栏不闭合（\`\`\` × ${FENCE}，奇数）——渲染会整段错乱"
  fi

  # 5. 内链文件存在性（只认带扩展名的真实文件路径，避免把并列列举文字当路径）
  # 注: 扩展名白名单曾缺 html/css/js/csv，导致死链漏检（Y-008 大修实测，扩展名见下行正则）。
  #     扫描范围 = SKILL.md 正文且止于 "## Changelog"——Changelog 是叙述区，提及的历史/示例路径
  #     不构成本 skill 内链（叙述性路径误报三案后的治本规则，Y-010 岁修）。
  #     references 内交叉引用因相对路径基准不一暂不扫（边界留岁修）。
  MISS_LINK=0
  BODY_PRECHANGELOG=$(awk '/^## Changelog/{exit} {print}' "$SKILL_MD")
  for p in $(printf '%s' "$BODY_PRECHANGELOG" | grep -oE '(references|templates|scripts|tools|assets)/[A-Za-z0-9._-]+\.(md|sh|json|py|yaml|yml|txt|html|css|js|csv|png|svg|gif)' | sort -u); do
    if [ ! -e "$SKILL_DIR/$p" ]; then
      fail "内链文件不存在: $p"
      MISS_LINK=1
    fi
  done
  [ "$MISS_LINK" -eq 0 ] && pass "内链文件全部存在（带扩展名路径）"

  # 6. 占位符残留（术语一致性深检交 LLM 勘验）
  PLACEHOLDER=$(grep -cE 'TODO|TBD|FIXME|【待填|\[待定' "$SKILL_MD" 2>/dev/null) || PLACEHOLDER=0
  if [ "$PLACEHOLDER" -eq 0 ]; then
    pass "无 TODO/TBD/占位符残留"
  else
    warn "发现 ${PLACEHOLDER} 处占位符（TODO/TBD/待填）——交付前清零"
  fi
fi

# 7. 疑似密钥文件扫描（只报存在，不读内容）
# 注: '*token*' 会撞前端「设计令牌」术语家族（tokens.css / design-tokens.md）——Y-008 大修实测误报，
#     按命名白名单排除；真密钥文件（api_token / access-token / *.key 等）仍命中。
#     tests/fixtures/ 整目录豁免——测试夹具的病灶是故意预埋的教具，不计宿主体检（Y-010 岁修）。
SECRET_HIT=0
for f in $(find "$SKILL_DIR" \( -name .git -o -name node_modules -o -path '*/tests/fixtures' \) -prune -o \
  \( -name '.env' -o -name '*.pem' -o -name 'id_rsa' -o -name '*token*' -o -name '*.key' \) -type f -print 2>/dev/null | head -8); do
  base=$(basename "$f")
  case "$base" in
    tokens.css|tokens.json|*design-token*|*design_token*|*-tokens.md|*-tokens.css) continue ;;  # 设计令牌，非密钥
  esac
  fail "疑似密钥文件: ${f#"$SKILL_DIR"/}（公开前必须移除；本脚本不读其内容）"
  SECRET_HIT=1
done
[ "$SECRET_HIT" -eq 0 ] && pass "未发现疑似密钥文件"

# 8. 测试资产存在性（只认独立测试文件——正文提及"测试 prompt"不算资产，防自述蒙混）
HAS_TEST=0
# 注: 路径匹配以 $SKILL_DIR 为根的相对路径（cd 后 find .）——绝对路径匹配 '*/tests/*' 会在
#     查勘对象本身位于宿主 tests/ 树下（如 fixtures 教具）时恒假阳性（Y-010 实测实例反向发现）。
if (cd "$SKILL_DIR" && find . \( -name .git \) -prune -o \( -iname '*test*prompt*' -o -iname 'test-prompts*' -o -iname 'evals*' -o -path './tests/*' \) -type f -print 2>/dev/null) | grep -q .; then
  HAS_TEST=1
fi
if [ "$HAS_TEST" -eq 1 ]; then
  pass "存在独立测试资产文件"
else
  if [ -f "$SKILL_MD" ] && grep -qE '测试 prompt|test prompt|验证与测试' "$SKILL_MD" 2>/dev/null; then
    warn "正文提及测试但无独立测试资产文件——「实测表现」记 0 分且总分上限 70；判据须落为带四件套的独立文件"
  else
    warn "无测试资产——勘验「实测表现」将记 0 分且总分上限 70（见 references/scoring.md）"
  fi
fi

echo ""
echo "【传播段 · 开源发布就绪度（发布目标=${TARGET_MODE}）】"

# P1. LICENSE
if [ -f "$SKILL_DIR/LICENSE" ] || [ -f "$SKILL_DIR/../LICENSE" ]; then
  pass "LICENSE 存在"
else
  prop_gap warn "缺 LICENSE——开源出门必备"
fi

# P2. README 钩子结构
README=""
[ -f "$SKILL_DIR/README.md" ] && README="$SKILL_DIR/README.md"
[ -z "$README" ] && [ -f "$SKILL_DIR/../README.md" ] && README="$SKILL_DIR/../README.md"
if [ -n "$README" ]; then
  HOOK_OK=0
  grep -qE '安装|Install|快速开始|Quick' "$README" && grep -qE '触发|Trigger|怎么用|Usage' "$README" && HOOK_OK=1
  if [ "$HOOK_OK" -eq 1 ]; then
    pass "README 含安装与触发小节"
  else
    prop_gap warn "README 缺安装/触发方式小节——首屏 10 秒讲不清"
  fi
else
  prop_gap fail "无 README——开源目标下首屏信任无从谈起（若本目录是装载副本而非发行仓库根：传播段检查请对源仓跑，或改用 --target internal）"
fi

# P3. demo 视觉产物及录制脚本
if find "$SKILL_DIR" "$SKILL_DIR/.." -maxdepth 2 \( -name '*.gif' -o -name '*.mp4' -o -name '*.webm' \) -type f -print 2>/dev/null | grep -q .; then
  pass "demo 视觉产物存在"
  if find "$SKILL_DIR" "$SKILL_DIR/.." -maxdepth 2 -name '*.tape' -type f -print 2>/dev/null | grep -q .; then
    pass "demo 录制脚本入库（可复现）"
  else
    prop_gap warn "有 demo 但缺录制脚本——showcase 应可复现，不摆拍"
  fi
else
  prop_gap warn "缺 demo GIF/视频——可见产物是首屏信任核心"
fi

# P4. 安装路径
if [ -n "$README" ] && grep -qE 'install\.sh|npx |cp -R|git clone' "$README" 2>/dev/null; then
  pass "README 含一行安装路径"
else
  prop_gap warn "缺一行安装命令——安装摩擦未消除"
fi

# P5. Runtime 中立性红灯（锁定单一 runtime 的措辞会让其他 agent/runtime 解析时判「不是给我用的」直接拒装）
# 只扫锁定性措辞，不扫路径本身（多平台路径并列是正当的）；frontmatter 触发词区豁免
RT_PATTERN='在 (Claude Code|Cursor|Codex) (里|中)|(Claude Code|Cursor|Codex) (skill|专用|用户专属)|(仅|只)(支持|适用于|限) ?(Claude Code|Cursor|Codex|Gemini CLI)|(Claude Code|Cursor|Codex) only'
RT_HITS=0
for doc in "$SKILL_MD" "$README"; do
  [ -n "$doc" ] && [ -f "$doc" ] || continue
  if [ "$doc" = "$SKILL_MD" ]; then
    HITS=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm!=1' "$doc" | grep -cE "$RT_PATTERN" 2>/dev/null) || HITS=0
  else
    HITS=$(grep -cE "$RT_PATTERN" "$doc" 2>/dev/null) || HITS=0
  fi
  if [ "$HITS" -gt 0 ]; then
    prop_gap warn "runtime 锁定措辞 ×${HITS}（${doc##*/}）——改为 runtime 中立表述或显式标注「runtime-specific」章节，否则跨 runtime 分发会被拒装"
    RT_HITS=$((RT_HITS+HITS))
  fi
done
[ "$RT_HITS" -eq 0 ] && pass "无 runtime 锁定措辞（中立性红灯零命中）"

echo ""
echo "── 汇总 ──"
echo "PASS: $PASS_N   WARN: $WARN_N   FAIL: $FAIL_N   INFO: $INFO_N"
if [ "$FAIL_N" -gt 0 ]; then
  echo "结论: 存在必须改项（FAIL）——先清零再进入勘验评分"
  exit 1
fi
echo "结论: 无必须改项；WARN 进入查勘报告 P1 清单，INFO 留作开源出门清单"
