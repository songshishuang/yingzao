# Tool Registry (repo-root shared resource)

This file lives at the monorepo root `tools/` and is shared by many skills.
A child skill references it via an upward relative path `../../tools/REGISTRY.md`.
Its real existence here is what makes the link checker's false-positive a bug, not a real dead link.
