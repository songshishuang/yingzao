#!/bin/bash
# 营造 yingzao · 一键安装脚本
# 用法：
#   ./install.sh                              # 装到 Claude Code (~/.claude/skills/)
#   ./install.sh claude-code                  # 同上
#   ./install.sh cursor --project /path/...   # 装到指定项目的 .cursor-plugin/
#   ./install.sh codex                        # 装到 ~/.codex/skills/
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
  codex          探测式：~/.codex/skills/ 已存在则装入，否则按官方约定创建；
                 若你的 Codex 用其他目录体系（如 plugins/ + AGENTS.md），用 --dest 指定
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
    *) echo "❌ 未知平台: ${PLATFORM}（支持 claude-code / cursor / codex / opencode）"; exit 1 ;;
esac

echo ""
echo "🎉 营造 yingzao 安装完成"
echo "👉 下一步：在 AI 会话里说「查勘 <某个 skill 路径>」即可开始第一次体检"
