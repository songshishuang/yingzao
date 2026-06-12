#!/bin/bash
# 营造 yingzao · 一键安装脚本
# 用法：
#   ./install.sh                              # 装到 Claude Code (~/.claude/skills/)
#   ./install.sh claude-code                  # 同上
#   ./install.sh cursor --project /path/...   # 装到指定项目的 .cursor-plugin/
#   ./install.sh codex                        # 装到 ~/.codex/plugins/...
#   ./install.sh opencode --project /path/... # 装到指定项目的 .opencode/

set -euo pipefail

SKILLS=(yingzao)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PLATFORM="${1:-claude-code}"
PROJECT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project) PROJECT_DIR="$2"; shift 2 ;;
        -h|--help)
            cat <<EOF
用法: $(basename "$0") <platform> [--project /path]

支持平台:
  claude-code    安装到 ~/.claude/skills/（用户全局，默认）
  cursor         安装到 <project>/.cursor-plugin/yingzao/ (必须 --project)
  codex          安装到 ~/.codex/plugins/yingzao/
  opencode       安装到 <project>/.opencode/plugins/yingzao/ (必须 --project)

含 1 个 skill：yingzao（Skill 打磨工坊：查勘快检 / 大修全流程）
EOF
            exit 0
            ;;
        *) shift ;;
    esac
done

case "$PLATFORM" in
    claude-code)
        DEST="$HOME/.claude/skills"
        mkdir -p "$DEST"
        for s in "${SKILLS[@]}"; do
            rm -rf "$DEST/$s"
            cp -R "$SCRIPT_DIR/$s" "$DEST/$s"
            echo "  ✅ $s → $DEST/$s"
        done
        ;;
    cursor)
        if [[ -z "$PROJECT_DIR" ]]; then
            echo "❌ Cursor 需要 --project <你的 Cursor 项目路径>"; exit 1
        fi
        DEST="$PROJECT_DIR/.cursor-plugin/yingzao"
        mkdir -p "$DEST"
        for s in "${SKILLS[@]}"; do
            rm -rf "$DEST/$s"
            cp -R "$SCRIPT_DIR/$s" "$DEST/$s"
            echo "  ✅ $s → $DEST/$s"
        done
        PLUGIN_JSON="$PROJECT_DIR/.cursor-plugin/plugin.json"
        if [[ ! -f "$PLUGIN_JSON" ]]; then
            cat > "$PLUGIN_JSON" <<EOF
{
  "name": "yingzao",
  "displayName": "营造 yingzao",
  "description": "Skill 打磨工坊：查勘快检 + 大修全流程，把能用的 skill 打磨到能交付",
  "version": "1.0.0",
  "skills": "./yingzao/"
}
EOF
            echo "  ✅ 生成 $PLUGIN_JSON"
        fi
        ;;
    codex)
        DEST="$HOME/.codex/plugins/yingzao"
        mkdir -p "$DEST"
        for s in "${SKILLS[@]}"; do
            rm -rf "$DEST/$s"
            cp -R "$SCRIPT_DIR/$s" "$DEST/$s"
            echo "  ✅ $s → $DEST/$s"
        done
        ;;
    opencode)
        if [[ -z "$PROJECT_DIR" ]]; then
            echo "❌ OpenCode 需要 --project <你的项目路径>"; exit 1
        fi
        DEST="$PROJECT_DIR/.opencode/plugins/yingzao"
        mkdir -p "$DEST"
        for s in "${SKILLS[@]}"; do
            rm -rf "$DEST/$s"
            cp -R "$SCRIPT_DIR/$s" "$DEST/$s"
            echo "  ✅ $s → $DEST/$s"
        done
        ;;
    *) echo "❌ 未知平台: $PLATFORM（支持 claude-code / cursor / codex / opencode）"; exit 1 ;;
esac

echo ""
echo "🎉 营造 yingzao 安装完成"
echo "👉 下一步：在 AI 会话里说「查勘 <某个 skill 路径>」即可开始第一次体检"
