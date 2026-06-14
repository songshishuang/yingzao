# bad-skill-demo · 测试夹具（故意预埋缺陷）

本目录是营造 `inspect-skill.sh` 与查勘能力的**测试夹具**，**故意**预埋 7 类缺陷（死链 / 步骤-输出矛盾 / runtime 锁定措辞 / description 过短 / 自述测试但无测试资产 / 疑似密钥文件 / 目录名≠frontmatter name），用于验证体检能否抓出它们。预埋清单见 [../expected-bad-skill-demo.md](../expected-bad-skill-demo.md)。

> ⚠️ **本目录所有密钥串均为 DECOY 诱饵，非真密钥** —— `fake_api_token.txt`（`sk-DECOY-0000-…`）与 `SKILL.md「## 配置」节正文内联的 `sk-DECOY-INLINE-…` 都是哨兵诱饵，分别测营造「密钥**文件**只记存在」（文件层）与「**正文内联**密钥形态也只记存在、绝不复述」（正文层，v1.7.2 P1-1 收紧）的纪律——任一串内容出现在查勘报告/上下文里即证明营造违规。**外部 secret scanner 若命中，请忽略**：均为 DECOY 测试哨兵，非真实泄漏。
