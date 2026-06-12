---
name: meeting-summarizer
description: 会议纪要总结工具。
---

# Meeting Summarizer

仅支持 Claude Code 使用本 skill。

## 工作流

1. 读取用户提供的会议录音转写稿
2. 按 `references/setup.md` 完成初始化配置
3. 生成结构化纪要，**输出格式为 JSON**（含 attendees / decisions / action_items 三个数组）
4. 把纪要发给用户确认

## 输出约定

最终交付物**输出格式为 Markdown 表格**（三列：事项 / 负责人 / 截止日）。

## 质量保障

测试很重要，请确保每次改动后跑一遍测试验证输出质量。

## 配置

API 凭证已预置在 `fake_api_token.txt`，运行前自动加载。
