# HTML 报告档 · 数据契约（v1.13）

> 查勘 / 大修**默认**在 markdown 报告之外**再出一份自包含 HTML**（结构化、直观、可外发）。
> 机制 = **数据与渲染分离**：打磨 Agent 只产「报告数据 JSON」，确定性脚本 `tools/render-report.py`
> 渲染成自包含纯静态 HTML（内联 CSS + 预算好的内联 SVG 雷达，**零 CDN / 零 JS**，断网双击可开、深浅色自适应）。
> Agent **不手写 HTML、不手算 SVG 坐标**（易错、不稳定）——只填数据，渲染交脚本。

## 用法

```
python3 tools/render-report.py <报告数据.json> <输出.html>
```

- **降级**：宿主无 `python3` → 落成步骤**跳过 HTML、只出 markdown**，并在报告与播报标注「因无 python3 未出 HTML 档」。HTML 是 markdown 的**叠加**，缺失不阻塞交付。
- HTML 与 markdown **同源同数据**：人话版、九维分、差距、验证门记录一致；markdown 仍是默认、可 diff、研发友好，HTML 主打直观/对外/给运营 PM。
- **脱敏**：外发版 HTML 同 markdown 规则——内部路径换代号；JSON 里就不要放真实内部路径（落成匾/执行计划等字段写代号）。

## 数据契约（JSON schema）

顶层：

| 字段 | 必填 | 取值 | 说明 |
|------|------|------|------|
| `kind` | 是 | `"full"` / `"quick"` | 大修 / 查勘 |
| `meta` | 是 | 对象 | 报告头元信息 |
| `human` | 推荐 | 对象 | 人话版区块（运营/PM 画像**必填**·研发可省） |
| `verdict` | full | 对象 | 落成匾结果卡 |
| `scores` | 推荐 | 数组 | 九维达成率（雷达图） |
| `headroom` | full 可选 | 对象 | 真实任务 before/after 对照条 |
| `gaps` | 推荐 | 数组 | 差距清单（含 V/A/K） |
| `rounds` | full 可选 | 数组 | 验证门记录时间线 |
| `sections` | 可选 | 对象 | 文本节（相地/访例/定式/…） |

各字段：

```jsonc
{
  "kind": "full",
  "meta": {"skill":"…","date":"YYYY-MM-DD","form":"方法论型","role":"PM","target":"开源","mode":"比样 best-of-3","run":"隔离实测"},
  "human": {                                  // 人话版·零术语·每条只说「什么问题→改完有何不同」
    "score_now": 94, "score_after": 94,
    "items": [{"problem":"白话问题","why":"为什么是问题","after":"改完用起来有什么不同"}]
  },
  "verdict": {"score_before":94,"score_after":94,"measured":"实测","niche":"一句话生态位","signature":"绝活","next":"下一步"},
  "scores": [                                 // 9 项·abbr 短名进雷达·score/full 算达成率
    {"abbr":"触发","score":7,"full":7}, {"abbr":"工作流","score":12,"full":12},
    {"abbr":"失败模式","score":11,"full":12}, {"abbr":"检查点","score":6,"full":6},
    {"abbr":"具体性","score":16,"full":17}, {"abbr":"资源","score":4,"full":4},
    {"abbr":"架构","score":11,"full":12}, {"abbr":"安全","score":6,"full":7},
    {"abbr":"实测","score":21,"full":23}
  ],
  "headroom": {"type":"技能依赖型 · 撞顶","note":"一句话诚实说明",
    "bars":[{"label":"装载版","pass":18,"total":20},{"label":"裸基线","pass":0,"total":20}]},
  "gaps": [                                   // adopted: true=采纳 / false=不采纳 / 省略=未定
    {"level":"P0","title":"差距标题","V":"怎么验证","A":"问题在哪·是否 skill 的锅","K":"别弄坏的能力","gain":"+0~+1","adopted":true}
  ],
  "rounds": [                                 // pass: true=过门 / false=弃稿 / null=未触发
    {"variable":"轮次·改的变量","result":"测试结果","gates":"①②③④","verdict":"采纳 patch","pass":true}
  ],
  "sections": {                              // 值 = 字符串 或 字符串数组（多段）
    "xiangdi":"相地结论…","fangli":["访例…"],"dingshi":"定式…","readme":"…","plan":["…"],"suixiu":"…"
  }
}
```

- **full** 的 `sections` 键：`xiangdi`(相地)/`fangli`(访例)/`dingshi`(定式)/`readme`(README建议)/`plan`(执行计划)/`suixiu`(岁修)。
- **quick** 的 `sections` 键：`sanwen`(相地三问)/`advice`(下一步建议)；quick 不渲染 verdict/headroom/rounds。
- 缺省字段安全跳过（不渲染对应区块），不报错。

## 设计原则（三处可见 · 不删机制）

1. **人话版优先**：HTML 顶部即「给非技术同事的人话版」（蓝卡·零术语），工程明细在后——对应 v1.12 [scoring 受众分层]。
2. **自包含**：单文件、内联 SVG、零外部依赖——外发/邮件/离线都能开。
3. **确定性可测**：渲染是纯函数，`tests/test-render-report.sh` 用夹具守护（改坏即门禁红）。
