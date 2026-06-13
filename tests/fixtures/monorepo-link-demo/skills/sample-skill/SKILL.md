---
name: sample-skill
description: A monorepo child skill that references a shared repo-root tool registry through an upward relative path, used as a regression fixture to verify the link checker does not false-positive on ../ parent paths while still catching genuine intra-skill dead links.
---

# Sample Skill

This skill lives inside a monorepo. For the shared tool registry, see the [tools registry](../../tools/REGISTRY.md) at the repository root.

It reads its own [real reference](references/real.md), which exists.

It also points at a [broken reference](references/does-not-exist.md) — a genuine dead link inside the skill directory that the checker MUST still catch.
