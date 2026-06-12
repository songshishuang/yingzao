#!/usr/bin/env bash
# 营造 · 规则预检（查勘第 2 步的零成本预过滤层）
# 双段式：基础段（团队复用就绪，恒定计入）+ 传播段（开源发布就绪，按发布目标定级）
# 用法: inspect-skill.sh <skill-dir> [--target internal|opensource]
#   <skill-dir> 为含 SKILL.md 的目录（单文件 skill 同样适用）
# 输出: 每条 PASS/WARN/FAIL/INFO + 严重度（必须改/应该改/最佳实践）；FAIL>0 时 exit 1
# 设计依据: docs/superpowers/specs/2026-06-12-yingzao-skill-polisher-design.md §5.1
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
  MISS_LINK=0
  for p in $(grep -oE '(references|templates|scripts|tools)/[A-Za-z0-9._-]+\.(md|sh|json|py|yaml|yml|txt)' "$SKILL_MD" 2>/dev/null | sort -u); do
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
SECRET_HIT=0
for f in $(find "$SKILL_DIR" \( -name .git -o -name node_modules \) -prune -o \
  \( -name '.env' -o -name '*.pem' -o -name 'id_rsa' -o -name '*token*' -o -name '*.key' \) -type f -print 2>/dev/null | head -5); do
  fail "疑似密钥文件: ${f#"$SKILL_DIR"/}（公开前必须移除；本脚本不读其内容）"
  SECRET_HIT=1
done
[ "$SECRET_HIT" -eq 0 ] && pass "未发现疑似密钥文件"

# 8. 测试 prompt 存在性
HAS_TEST=0
if find "$SKILL_DIR" \( -name .git \) -prune -o \( -iname '*test*prompt*' -o -iname 'test-prompts*' -o -iname 'evals*' \) -type f -print 2>/dev/null | grep -q .; then
  HAS_TEST=1
elif [ -f "$SKILL_MD" ] && grep -qE '测试 prompt|test prompt|验证与测试|## 测试' "$SKILL_MD" 2>/dev/null; then
  HAS_TEST=1
fi
if [ "$HAS_TEST" -eq 1 ]; then
  pass "存在测试 prompt 资产或测试章节"
else
  warn "无测试 prompt——勘验「实测表现」将记 0 分且总分上限 70（见 references/scoring.md）"
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
  prop_gap fail "无 README——开源目标下首屏信任无从谈起"
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

echo ""
echo "── 汇总 ──"
echo "PASS: $PASS_N   WARN: $WARN_N   FAIL: $FAIL_N   INFO: $INFO_N"
if [ "$FAIL_N" -gt 0 ]; then
  echo "结论: 存在必须改项（FAIL）——先清零再进入勘验评分"
  exit 1
fi
echo "结论: 无必须改项；WARN 进入查勘报告 P1 清单，INFO 留作开源出门清单"
