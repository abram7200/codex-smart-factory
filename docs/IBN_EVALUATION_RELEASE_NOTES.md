# IBN × Codex Smart Factory — Evaluation Package v0.1.0

**Type:** Architecture and integration *evaluation* — **PRE-RELEASE**.

**Source revision:** `review/ibn-integration-evaluation-20261104`, based on Smart Factory `v1.1.4` / `c74d25baf17020aad9bdabe3fad063f1faf2cea0`.

This is a **public documentation-only release** for an autonomous engineering agent to review and implement a future integration. It is **NOT** a tested installer, completed IBN connector, deployed Windows integration, or an approved engineering product. Do not merge or roll out to production without the implementation and tests.

## Included public documents

- `docs/IBN_SMART_FACTORY_EVALUATION.md` — review of actual Smart Factory code, engineering ownership and 30 acceptance gates.
- `docs/AGENT_ADAPTER_MATRIX.md` — capability-aware, per-client instructions and adapter contracts; 10 agent gates.
- `docs/ENGINEERING_INTENT_AND_REPORTING.md` — instruction fidelity, evidence-first engineering, Skill selection, token/context optimization, verified-only learning and reports; 12 quality gates.
- `docs/IBN_AGENT_IMPLEMENTATION_MISSION.md` — actionable implementation mission for Codex or another supported development agent.

Total: **52 explicit acceptance gates**, all requiring measured, local runtime evidence.

## Key code issues requiring correction

- SF-01: global Codex `AGENTS.override.md` injection conflicts with existing IBN/user instructions.
- SF-02: `Smart-Exec.ps1` non-interactive `approval_policy="never"` and write scope can be unsafe for native engineering files.
- SF-03: English-centric `Router.ps1` needs Arabic/English engineering-aware classification.
- SF-04: the one-file CMD installer does not visibly verify the exact downloaded tag archive against an independently trusted artifact identity before executing.

## Agent-specific integration

Codex gets its native Smart Factory runtime plus verified IBN integration. Claude Code, Cursor, OpenCode, Gemini CLI, Antigravity, GitHub Copilot and other detected agents should get **only genuinely supported** native instructions, hooks and IBN tools. Do not copy Codex's entire global Core into every agent.

No central server, extra paid API, unsupported agent hooks, or competing IBN Memory/Graphify/Brain.

## Safety and privacy

The public ZIP contains **only the four public Markdown documents above**. It deliberately excludes internal IBN source files, licensed engineering standards, internal Drive links, private source registers, client/project data, installed-user paths, credentials and agent transcripts.

The separate private agent ZIP previously prepared for the owner is **not a public release asset**.

## Validation status

Documentation was compared with the actual Smart Factory source and authorized IBN evidence. The 52 cross-system integration/quality gates are **NOT TESTED** on an actual engineer Windows workstation in this release.

The ZIP SHA-256 file checks download integrity only. It is not a signature or proof of engineering validation.

**Intended audience:** developer agents and engineers planning a secure, per-engineer Windows integration.
