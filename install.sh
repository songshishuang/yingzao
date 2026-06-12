#!/bin/bash
# 营造 yingzao · 一键安装脚本
# 用法：
#   ./install.sh                              # 装到 Claude Code (~/.claude/skills/)
#   ./install.sh claude-code                  # 同上
#   ./install.sh cursor --project /path/...   # 装到指定项目的 .cursor-plugin/
#   ./install.sh codex                        # 装到 ~/.codex/skills/
#   ./install.sh opencode --project /path/... # 装到指定项目的 .opencode/
# 重装保护：references/case-log.md 与 case-map.local.md 是运行期本地状态（打磨台账与映射），
#           重装时自动备份并还原，不会被源仓版本覆盖。

set -euo pipefail

SKILLS=(yingzao)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_STATE_FILES=(case-log.md case-map.local.md)

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
  codex          安装到 ~/.codex/skills/
  opencode       安装到 <project>/.opencode/plugins/yingzao/ (必须 --project)

含 1 个 skill：yingzao（Skill 打磨工坊：查勘快检 / 大修全流程）
重装不会丢失本地打磨台账（case-log.md / case-map.local.md 自动保留）
EOF
            exit 0
            ;;
        *) shift ;;
    esac
done

install_skills_to() {  # $1 = 目标根目录
    local dest_root="$1"
    mkdir -p "$dest_root"
    for s in "${SKILLS[@]}"; do
        local dest="$dest_root/$s"
        local tmp_state=""
        if [[ -d "$dest/references" ]]; then
            tmp_state="$(mktemp -d)"
            for f in "${LOCAL_STATE_FILES[@]}"; do
                [[ -f "$dest/references/$f" ]] && cp "$dest/references/$f" "$tmp_state/$f"
            done
        fi
        rm -rf "$dest"
        cp -R "$SCRIPT_DIR/$s" "$dest"
        if [[ -n "$tmp_state" ]]; then
            local restored=""
            # case-map.local.md：源仓被 gitignore 永不含它——本地版本无条件还原
            if [[ -f "$tmp_state/case-map.local.md" ]]; then
                cp "$tmp_state/case-map.local.md" "$dest/references/case-map.local.md"
                restored="映射"
            fi
            # case-log.md：保「已大修 skill 数」计数更大的一方（本地新=纯使用者运行态；源仓新=开发侧已更新）
            if [[ -f "$tmp_state/case-log.md" && -f "$dest/references/case-log.md" ]]; then
                local n_local n_src
                n_local=$(grep -oE '已大修 skill 数：[0-9]+' "$tmp_state/case-log.md" | grep -oE '[0-9]+' || echo 0)
                n_src=$(grep -oE '已大修 skill 数：[0-9]+' "$dest/references/case-log.md" | grep -oE '[0-9]+' || echo 0)
                if [[ "${n_local:-0}" -gt "${n_src:-0}" ]]; then
                    cp "$tmp_state/case-log.md" "$dest/references/case-log.md"
                    restored="${restored:+$restored+}台账(本地计数 $n_local > 源仓 $n_src)"
                fi
            fi
            rm -rf "$tmp_state"
            if [[ -n "$restored" ]]; then
                echo "  ✅ $s → $dest（已保留本地状态：$restored）"
                continue
            fi
        fi
        echo "  ✅ $s → $dest"
    done
}

case "$PLATFORM" in
    claude-code)
        install_skills_to "$HOME/.claude/skills"
        ;;
    cursor)
        if [[ -z "$PROJECT_DIR" ]]; then
            echo "❌ Cursor 需要 --project <你的 Cursor 项目路径>"; exit 1
        fi
        install_skills_to "$PROJECT_DIR/.cursor-plugin/yingzao"
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
        # Codex 个人 skill 目录为 ~/.codex/skills/<skill>/SKILL.md（实测核验，plugins/ 加载不到）
        install_skills_to "$HOME/.codex/skills"
        ;;
    opencode)
        if [[ -z "$PROJECT_DIR" ]]; then
            echo "❌ OpenCode 需要 --project <你的项目路径>"; exit 1
        fi
        install_skills_to "$PROJECT_DIR/.opencode/plugins/yingzao"
        ;;
    *) echo "❌ 未知平台: $PLATFORM（支持 claude-code / cursor / codex / opencode）"; exit 1 ;;
esac

echo ""
echo "🎉 营造 yingzao 安装完成"
echo "👉 下一步：在 AI 会话里说「查勘 <某个 skill 路径>」即可开始第一次体检"
