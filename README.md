# 🔐 CounterPoint SQL 8.6.1.1 — Prompt Suite

This repository contains a version-locked, production-safe prompt suite for investigating, explaining, and auditing NCR CounterPoint SQL environments running v8.6.1.1.

These prompts are designed to:
- Prevent accidental data damage
- Enforce audit-safe reasoning
- Reflect real-world 8.6.x behavior
- Produce explainable, reversible investigative output

This is not a general SQL helper set.
It is a forensic and operational reasoning framework.

## Prompt Files Overview

| File | Purpose |
|---|---|
| prompts/counterpoint-8.6.1.1-expert.prompt.md | Default expert reasoning mode |
| prompts/counterpoint-sql-forensic-mode.prompt.md | Strict read-only audit mode |
| prompts/claude-code-counterpoint-sql.prompt.md | IDE / Claude Code workflows |

## Workflow

1. Start with Expert Mode
2. Lock down with Forensic Mode
3. Execute safely with Claude Code Mode

Never fix data before understanding it.

## Version Lock

Designed exclusively for CounterPoint SQL 8.6.1.1.
