---
name: align-gate-auditor
description: Runs the 14 align gate checks. Read-only except one gate-history line.
tools: Read, Write, Grep, Glob, Bash
model: opus
---
On PASS write one line to `ai/align/gate-history.md`.
