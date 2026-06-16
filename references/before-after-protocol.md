# 验证门① · 真实任务 before/after 盲评协议（v1.10）

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
| ④ 评委（盲评 panel） | 两份**匿名**输出（A/B 随机 + **换序双判**）+ 题面判据 | 胜负 + 双方 0-10 分 + 理由 | **不看任何 SKILL.md**、不知谁是原版；多数票；**长度归一、惩罚冗长** |

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

## 换序双判（M1 · v1.10 · 消位置噪声）

LLM 评委有位置偏置：换 A/B 顺序约 1/3 会翻转判定（**YZ-POSBIAS-D1 实测**同族单评委一致率 0.667、首位选择率 0.389/p≈0.077 无系统偏=**高噪型**）。故每 (题,评委) 判**两次**——序 AB（Response1=A）与序 BA（Response1=B），scores.json 各记一条带 `order`。`eval-harness.sh` 检测到 `order` 字段即进**换序双判模式**：同评委**两序都判 cand 优于 orig 才记该评委胜**，两序矛盾=不计胜（保守消噪、宁缺毋滥）。处方同 MT-Bench(2306.05685)。
> **决策依据（YZ-POSBIAS-D1）**：判定为「高噪型」（翻转是随机噪声、非系统偏一侧）→ 换序双判成立且**价值最大**（专消随机翻转）；若实测为「系统型」（首位选择率显著偏一侧）则应改**跨族复判**——同族双判会把系统偏好转成平局、毁信号。

## 长度归一 / 惩罚冗长（M2 · v1.10）

评委须**对等长度比较**：两输出长度差大时先判长输出的增量是否真有信息量；注水 / 重复列表 / 空泛样板一律判负，**评分不得因更长而更高**（"重复列表攻击"曾使弱判官 91% 误判，MT-Bench 2306.05685）。可选在 scores.json 记 `cand_len/orig_len`（输出字符数），`eval-harness.sh` 见 cand 远长(>1.5×)且判胜即打注水告警。

## scores.json 格式（v2 · 向后兼容 · 喂给 eval-harness.sh）

```json
[
  {"prompt":"p1","judge":1,"order":"AB","orig":8.5,"cand":9.0,"bare":7.0,"cand_len":1200,"orig_len":1100},
  {"prompt":"p1","judge":1,"order":"BA","orig":8.6,"cand":9.1},
  {"prompt":"p2","judge":1,"orig":9.0,"cand":8.5}
]
```
- **必填** `prompt / orig / cand`（缺则 harness 判数据错、降级不静默当真）。
- **可选** `judge`（评委号·同 prompt 多条求均值）、`bare`（裸基线·算 skill_lift）、`order`（"AB"/"BA"·触发换序双判）、`cand_len/orig_len`（输出字符数·触发长度告警）、`set`（"gate"/"holdout"·Wave2 D2 留位）、`weight`（留位）。
- **v1.10 冻结**：未知字段一律忽略（向后兼容 v1）；Waves 2-3（D2 holdout / D3 校准 / D7 verifier 分）在此 schema **加列、不改结构**。分值 0-10。
