#!/usr/bin/env bash
# 营造 · 按 manifest 拉取外部 fixture(F2/F3) 到 gitignore 工作区(.work/) 并验 SHA256 防漂移。
# 外部 skill 不入仓库(license/体积)；本脚本保证「拉到的就是锁定快照」。
# 注：F2/F3 第三方仓库 URL 已于开源时脱敏为占位；重跑召回验证请填回真实地址：
#     F2_REPO=github.com/<owner>/<repo> F3_REPO=github.com/<owner>/<repo> bash fetch-fixtures.sh
# 用法: fetch-fixtures.sh [F2|F3|all]
set -uo pipefail
cd "$(dirname "$0")"
WORK=".work"; mkdir -p "$WORK"
fetch() { # id repo commit path want_sha256
  local id="$1" repo="$2" commit="$3" path="$4" want="$5" d="$WORK/$1"
  rm -rf "$d"
  git clone -q "https://$repo.git" "$d" >/dev/null 2>&1 && git -C "$d" checkout -q "$commit" 2>/dev/null \
    || { echo "✗ $id clone/checkout 失败"; return 1; }
  local got; got=$(shasum -a 256 "$d/$path/SKILL.md" | awk '{print $1}')
  if [ "$got" = "$want" ]; then echo "✓ $id SKILL.md SHA256 一致 @${commit:0:10}"; else echo "✗ $id 快照漂移 got=$got want=$want"; return 1; fi
}
do_f2(){ fetch F2 "${F2_REPO:-redacted-external-repo-f2}" 4a3c05b69e64f4925f7fc65c88890f614f79caf0 c-level-advisor/c-level-agents/skills/caio-review 4082151af5f6a3966a45b8e5ac7a5e13b55065d5615574130df4f51954517e23; }
do_f3(){ fetch F3 "${F3_REPO:-redacted-external-repo-f3}" bee3f2f42c9ead9271af59a6d2082ed8aca8b3d3 skills/cold-email b7f8d793169a5111c857e5720c6b80028686cc95d5a0d0d6570957c2710aff9e; }
case "${1:-all}" in
  F2) do_f2 ;;
  F3) do_f3 ;;
  all) do_f2; do_f3 ;;
  *) echo "用法: $(basename "$0") [F2|F3|all]" >&2; exit 2 ;;
esac
