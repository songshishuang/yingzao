#!/bin/bash
# 营造 yingzao · 一键安装脚本
# 用法：
#   ./install.sh                              # 装到 Claude Code (~/.claude/skills/)
#   ./install.sh claude-code                  # 同上
#   ./install.sh cursor --project /path/...   # 装到指定项目的 .cursor-plugin/
#   ./install.sh codex                        # 装到 ~/.agents/skills/（Codex 官方用户级路径）
#   ./install.sh opencode --project /path/... # 装到指定项目的 .opencode/
# 重装保护（v1.4 分层）：本地扩展层 *.local.md 无条件保留使用者积累；主线核心（含 case-log.md
#           作者公开战绩）随仓覆盖。case-map.local.md 含真实路径，源端无条件删除（隐私闸）。

set -euo pipefail

SKILLS=(yingzao)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_STATE_FILES=(case-log.local.md case-map.local.md anti-patterns.local.md roles.local.md)

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
  codex          装到 ~/.agents/skills/（Codex 官方用户级标准路径，放入即自动发现）；
                 ~/.codex/ 存在时兼容补装 ~/.codex/skills/；仍不识别用 --dest 指定
  opencode       安装到 <project>/.opencode/plugins/yingzao/ (必须 --project)

通用选项:
  --dest <dir>   覆盖任何平台的默认安装根目录（你的环境与默认约定不符时的逃生门）

含 1 个 skill：yingzao（Skill 打磨工坊：查勘快检 / 大修全流程）
重装不会丢失本地扩展层（*.local.md：台账/反模式/团队源/映射 自动保留）
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
        mkdir -p "$dest"
        # ── 按 tools/skill-manifest.txt 白名单安装（v1.5 扁平化）──
        # 扁平化后仓库根混了工程文件，只装清单内的 skill 核心；
        # install.sh / tools/check-release.sh / .github / assets / marketplace.json / VERSION / README / docs 等工程物不随装。
        while IFS= read -r item; do
            [[ -z "$item" || "$item" == \#* ]] && continue
            [[ -e "$SCRIPT_DIR/$item" ]] || continue
            mkdir -p "$dest/$(dirname "$item")"
            cp -R "$SCRIPT_DIR/$item" "$dest/$item"
        done < "$SCRIPT_DIR/tools/skill-manifest.txt"
        # ── 隐私安全闸（P0）──
        # case-map.local.md 含真实路径映射 + 岁修计数（本机运行态）。cp -R 会把开发机源端的
        # 一并带到目标 → 从开发机装到任何新 runtime/团队目录都会泄漏。无条件先删源端带来的，
        # 只允许从目标端原有备份还原（新装机器天然无此文件 → 岁修计数从 0 起）。
        rm -f "$dest/references/case-map.local.md"
        # ── 本地扩展层重装保护（v1.4 分层）──
        # 还原目标端原有的 *.local（保留使用者岁修积累，不被源端出厂空壳模板覆盖）；
        # 首次安装目标端无备份：case-map 保持删除态，其余 .local 用源端出厂空壳。
        local restored=""
        if [[ -n "$tmp_state" ]]; then
            for f in "${LOCAL_STATE_FILES[@]}"; do
                if [[ -f "$tmp_state/$f" ]]; then
                    cp "$tmp_state/$f" "$dest/references/$f"
                    restored="${restored:+$restored, }$f"
                fi
            done
            rm -rf "$tmp_state"
        fi
        if [[ -n "$restored" ]]; then
            echo "  ✅ $s → ${dest}（已保留本地扩展层：${restored}）"
        else
            echo "  ✅ $s → $dest"
        fi
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
            # 版本号从 VERSION 文件读取（唯一真相源，check-release.sh 校验四处一致）
            YZ_VERSION=$(tr -d ' \n' < "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "")
            cat > "$PLUGIN_JSON" <<EOF
{
  "name": "yingzao",
  "displayName": "营造 yingzao",
  "description": "Skill 打磨工坊：查勘快检 + 大修全流程，把能用的 skill 打磨到能交付",
  "version": "${YZ_VERSION:-0.0.0}",
  "skills": "./yingzao/"
}
EOF
            echo "  ✅ 生成 $PLUGIN_JSON"
        fi
        ;;
    codex)
        # Codex Agent Skills（2025.12+）用户级标准路径 = ~/.agents/skills/
        #   （OpenAI 官方 developers.openai.com/codex/skills 与 /concepts/customization 双处确认）。
        # 加载机制：放入即自动发现；若未出现，重启 Codex 触发 skill 目录 rescan，无需改 config.toml。
        # 旧版/部分第三方文档用 ~/.codex/skills/：官方路径为主，~/.codex/ 存在时补装一份兼容，
        #   Codex 只加载它认的那个，不冲突。仍不识别的环境用 --dest 逃生门。
        install_skills_to "$HOME/.agents/skills"
        if [[ -d "$HOME/.codex" ]]; then
            install_skills_to "$HOME/.codex/skills"
            echo "  ℹ️ 已双装：~/.agents/skills/（官方标准）+ ~/.codex/skills/（兼容旧约定）"
        else
            echo "  ℹ️ 已装入官方标准路径 ~/.agents/skills/"
        fi
        echo "     若 Codex 未识别，重启 Codex 触发 rescan；仍不识别用 --dest 指定目录。"
        ;;
    opencode)
        if [[ -z "$PROJECT_DIR" ]]; then
            echo "❌ OpenCode 需要 --project <你的项目路径>"; exit 1
        fi
        install_skills_to "$PROJECT_DIR/.opencode/plugins/yingzao"
        ;;
    *) echo "❌ 未知平台: ${PLATFORM}（支持 claude-code / cursor / codex / opencode）"; exit 1 ;;
esac

echo ""
echo "🎉 营造 yingzao 安装完成"
echo "👉 下一步：在 AI 会话里说「查勘 <某个 skill 路径>」即可开始第一次体检"
