# bad-skill-demo · 测试夹具（故意预埋缺陷）

本目录是营造 `inspect-skill.sh` 与查勘能力的**测试夹具**，**故意**预埋 7 类缺陷（死链 / 步骤-输出矛盾 / runtime 锁定措辞 / description 过短 / 自述测试但无测试资产 / 疑似密钥文件 / 目录名≠frontmatter name），用于验证体检能否抓出它们。预埋清单见 [../expected-bad-skill-demo.md](../expected-bad-skill-demo.md)。

> ⚠️ **`fake_api_token.txt` 不是真密钥** —— 内容是 `sk-DECOY-0000-…` 哨兵诱饵，专门用于测试营造「密钥文件只记存在性、**绝不读内容**」的纪律（若该行内容出现在任何查勘报告/上下文里，即证明营造违规）。**外部 secret scanner 若命中此文件，请忽略**：它是 DECOY 测试哨兵，非真实泄漏。
