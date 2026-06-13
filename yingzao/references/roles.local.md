# 团队内部源 · 本地配置（本地扩展层 · 使用者可写 · 升级保留）

> 本文件属**本地扩展层**：营造主线（SKILL.md / 其他 references）只读，此文件由你自由配置。
> 营造访例阶段会读取此处登记的内部源；升级重装时 install.sh 自动保留本文件，不被主线覆盖。
> 内部源条目**只进内部版报告**；可外发版一律以代号（内部对标 #1）指代。

## 团队内部源（全岗位共享，可选配置）

> 配置后访例阶段**优先扫内部源**——对标自家同事的同类 skill，比对标外网更贴近团队互相看齐的场景。未配置自动跳过，不影响流程。

```yaml
# 在此登记（可多条），示例：
# internal_sources:
#   - type: git
#     url: git@git.internal.example.com:ai/team-skills.git
#     note: 团队 skill 主仓
#   - type: dir
#     path: /Volumes/shared/agent-skills/
#     note: 内网共享目录
internal_sources: []
```
