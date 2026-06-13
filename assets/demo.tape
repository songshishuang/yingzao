# 营造 demo 录制脚本（vhs · https://github.com/charmbracelet/vhs）
# 状态：本机暂无 vhs 环境——当前 README 使用 demo-terminal.svg（输出逐字取自真实运行，
#       数据源 assets/demo-run.txt）；有 vhs 环境后执行 `vhs assets/demo.tape` 出真 GIF 替换。
# 纪律：用真实运行写这盘带子，不要摆拍。

Output assets/demo.gif

Set FontSize 15
Set Width 1200
Set Height 720
Set Theme "Catppuccin Mocha"
Set TypingSpeed 40ms
Set Padding 14

Type "# 体检一个有病的 skill ——"
Enter
Type "bash tools/inspect-skill.sh tests/fixtures/bad-skill-demo --target opensource"
Enter
Sleep 4s

Type "# 体检营造自己（岁修之后）——"
Enter
Type "bash tools/inspect-skill.sh . --target opensource"
Enter
Sleep 4s
