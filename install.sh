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
CUSTOM_DEST=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project) PROJECT_DIR="$2"; shift 2 ;;
        --dest) CUSTOM_DEST="$2"; shift 2 ;;
        -h|--help)
            cat <<EOF
用法: $(basename "$0") <platform> [--project /path] [--dest /custom/skills/root]

支持平台:
  claude-code    安装到 ~/.claude/skills/（用户全局，默认）
  cursor         安装到 <project>/.cursor-plugin/yingzao/ (必须 --project)
  codex          探测式：~/.codex/skills/ 已存在则装入，否则按官方约定创建；
                 若你的 Codex 用其他目录体系（如 plugins/ + AGENTS.md），用 --dest 指定
  opencode       安装到 <project>/.opencode/plugins/yingzao/ (必须 --project)

通用选项:
  --dest <dir>   覆盖任何平台的默认安装根目录（你的环境与默认约定不符时的逃生门）

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

# --dest 优先：用户显式指定即覆盖一切平台默认
if [[ -n "$CUSTOM_DEST" ]]; then
    install_skills_to "$CUSTOM_DEST"
    echo ""
    echo "🎉 营造 yingzao 安装完成（自定义目录）"
    echo "👉 下一步：在 AI 会话里说「查勘 <某个 skill 路径>」即可开始第一次体检"
    exit 0
fi

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
        # Codex 各版本/配置的目录约定不一，探测式选路：
        # 机器上 ~/.codex/skills/ 已存在（说明本机 Codex 认这个约定）→ 装入；
        # 不存在 → 按当前官方约定创建 skills/ 并提示核对；
        # 用 plugins/ + AGENTS.md 体系的环境 → ./install.sh codex --dest ~/.codex/plugins/yingzao
        if [[ -d "$HOME/.codex/skills" ]]; then
            install_skills_to "$HOME/.codex/skills"
        else
            install_skills_to "$HOME/.codex/skills"
            echo "  ⚠️ 本机原无 ~/.codex/skills/，已按当前 Codex 约定创建；若你的 Codex 加载不到，"
            echo "     请核对其文档后用 --dest 指定实际目录（如 plugins 体系需配 ~/.codex/AGENTS.md 引用）"
        fi
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
