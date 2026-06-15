# 验证门① · 真实任务 before/after 盲评协议（v1.9）

> 验证门①要的不是"文档变规整"，而是"**真实任务输出变好**"。本协议把这件事固化成可复现流程，杜绝门①退化为数关键词/看结构。**结构分↑≠输出分↑**——这条是铁律。
> 蒸馏自 2026-06-15 对 yingzao 自身的全量真实评测（50 真实社区 skill）。确定性部分由 `tools/eval-harness.sh` 承担，判断部分由隔离子 Agent 走本协议。

## 为什么要反循环（被它打回过的坑）

最早一版自评是"同一个模型既改写又打分 + 给每个 skill 套同一段样板、再数样板词给分"——改写者奖励的正是评分者要的，**candidate 必赢、证明不了真有效**。本协议用**四个互不共享上下文的角色**打破循环。

## 四角色（互不共享上下文）

| 角色 | 输入 | 产出 | 隔离铁律 |
|------|------|------|----------|
| ① 营造（改写者） | 原版全文 + 方法论 | candidate + 预测增益区间 | 读过全文；**不出题、不评分** |
| ② 命题（独立出题） | 仅 skill 的**声明用途** | K≥2 道真实任务题（四件套） | **不看 candidate**，按领域出题防偏向 |
| ③ 执行（隔离跑） | **单一**版本 SKILL.md + 一道题 | 任务输出 | 不知拿的是哪版、不知在被测（禁例 17） |
| ④ 评委（盲评 panel） | 两份**匿名**输出（A/B 随机）+ 题面判据 | 胜负 + 双方 0-10 分 + 理由 | **不看任何 SKILL.md**、不知谁是原版；多数票 |

三道防循环闸：出题者≠改写者（否则题偏向 candidate）／ 执行者每次只见一个版本（否则跨版本污染）／ 评委只见**任务输出**不见 skill 文本（否则又退化成数关键词）。

## A/B 盲化（确定性、两端可复算）

每 (case, 题) 用确定性 parity 决定原版落 A 还是 B 槽——`origIsA = (sum(charCodes(caseId)) + 题序号) % 2 == 0`。执行者把输出写到 `runs/p{n}_{A|B}.md`（按 parity），评委只读 A/B、不知映射；聚合时同公式复算把 A/B 还原成 原版/候选。

## 裸基线三方（headroom 确认，可选但强烈建议）

再加一类 **裸基线**（完全不给 skill、禁读 skill 目录、剥离全局注入跑同题），评委三方绝对打分得：
- **skill_lift = 原版 − 裸基线**：skill 本身值不值（≈0 即"底模掩盖型"，改它也难见效）。
- **overhaul_lift = 候选 − 原版**：大修值不值。
这把"增益小"区分成"skill 没发力"还是"大修没用"，直接支撑画样的 headroom 预判。

## runtime 感知隔离

- **Claude Code**：起隔离子 Agent（Task / workflow，必要时 worktree 隔离模式）。
- **Codex（≥2026-03 Subagents）**：`~/.codex/agents/*.toml` 定义执行/评委 Agent + 自动 git worktree + 每 Agent `sandbox_mode="read-only"`（**工具层硬隔离**，连含副作用的题也能在只读沙箱内实测）。注意默认 `max_threads=6 / max_depth=1`——本门须从顶层 agent 跑，或调高 `max_depth`。
- **弱宿主**（纯 Copilot / ChatGPT 无子 Agent）：做不到隔离 → 门①只能记**估分、不得记过门**（接 SKILL 降级链）。

## 过门判据（确定性，由 eval-harness.sh 算）

记每 (题, 评委) 的 `orig / cand`（及可选 `bare`）到 `scores.json`，跑 `bash tools/eval-harness.sh <run-dir>`：
1. **门①通过** = ≥2 道题的 candidate 平均分**优于**原版，且总体 `realized_gain = mean(cand) − mean(orig) > 0`，且**无明显回归**（无单题 cand 比 orig 低 >1.0）。
2. **边际复测**：某题分差 <1.0 或评委分歧 → 该题加跑一轮，仍微弱判未过门（宁缺毋滥）。
3. **棘轮**：分数只升不降，不过门直接丢弃候选。
4. 结果与 skill_lift / overhaul_lift 一并写入报告 §7。

## scores.json 格式（喂给 eval-harness.sh）

```json
[
  {"prompt":"p1","judge":1,"orig":8.5,"cand":9.0,"bare":7.0},
  {"prompt":"p1","judge":2,"orig":8.0,"cand":8.5,"bare":6.5},
  {"prompt":"p2","judge":1,"orig":9.0,"cand":8.5}
]
```
（`bare` 可选；同一 prompt 多条=多评委，自动求均值。分值 0-10。）
