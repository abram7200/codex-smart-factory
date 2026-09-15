# Codex Smart Factory

A free, open-source, Windows-first operating layer for OpenAI Codex that makes task execution more disciplined, context-efficient, project-aware, and model-aware without replacing Codex or installing a third-party proxy.

## What makes this build different

The essential behavior is **not** hidden behind a tiny trigger file.

`src/CORE_AGENTS.md` is the single authoritative operating brain. The installer composes that **full Core** into the global Codex `AGENTS.override.md`, so the rules are present from session start. Optional scripts automate model routing, project discovery, health checks, and analytics, but correctness does not depend on Codex deciding to open another Markdown reference later.

This design deliberately does **not** copy the Core into every repository. Codex already combines global instructions with project instructions, while project AGENTS files share a cumulative byte budget. Duplicating the Core inside repositories can waste context and truncate the more-specific rules that matter most.

## Features

- Full always-on global Core: retrieval, context management, debugging, implementation, verification, subagents, safety, communication, and model routing.
- Preserves pre-existing global Codex instructions across install, update/reinstall, repair, and uninstall.
- Does not overwrite project `AGENTS.md` / `AGENTS.override.md`.
- Finds old projects from surviving Codex session/history metadata.
- Automatically learns new projects from session CWDs.
- Central project profiles; no repository pollution required.
- Local, deterministic model/reasoning classifier.
- Live Codex model catalog discovery with cache/bundled fallbacks.
- Benefit-gated exact-model `codex exec` workers.
- Token-saver / balanced / max-quality routing profiles.
- Hidden/internal model exclusion.
- No automatic Ultra.
- Full rollout-backed boost self-check.
- Token usage and routing decision reports.
- Backups, repair, uninstall, CI tests.
- No remote installer piping, no proxy, no credential access.

## Install

1. Download or clone the repository.
2. Double-click `CODEX_SMART_FACTORY.cmd`.
3. Choose **1 — FULL INSTALL / UPDATE**.
4. Restart Codex once.
5. Ask Codex:

```text
Check if you are boosted or no?
```

A fully active session should begin with a status similar to:

```text
BOOSTED: YES | SmartFactory=1.0.0 | GlobalCore=ON | SessionInjected=YES | Router=ON(balanced) | Watcher=ON | ProjectRegistry=ON
```

If installation is correct but the current Codex session started before installation, the status reports `PENDING_RESTART` instead of pretending the Core was injected.

## Unified Mission Control

Smart Factory treats planning, execution, model selection, discoveries, verification, checkpointing, and resume as **one state machine**, not separate skills.

For a non-trivial plan or long-running task it creates:

```text
.codex-smart-factory/
├── MISSION.md
├── TASKS.md
├── tasks/T001.md
├── tasks/T002.md
├── PROGRESS.md
├── FINDINGS.md
├── RESUME-FROM-HERE.md
└── mission.json
```

Every task records its ID, status, why, dependencies, related tasks, relationship type, discovery parent, scope, acceptance criteria, verification, risk, **best model**, reasoning effort, **why that model**, and **model actually used**.

The integrated loop is:

```text
Plan → Task DAG → model route → quota preflight → execute
     → register discoveries → verify → checkpoint → next task
```

Unexpected bugs or required edits are registered before unrelated implementation as `blocker`, `required`, `related`, `follow-up`, or `out-of-scope`. Blocker/required discoveries become dependencies in the same graph.

`RESUME-FROM-HERE.md` is the deterministic first read after a crash, app close, context compaction, usage pause, or new session. Codex resumes the recorded task instead of rebuilding the plan from memory.

Mission Control reads Codex rate-limit telemetry when available. Default policy stops safely before new work when the 5-hour window reaches 15% remaining, stops at 10% weekly remaining, and refuses heavy routed work below 25% of the 5-hour window. If telemetry is unavailable, conservative session-time checkpoints are used instead.

## Smart model routing

Codex does not expose a universally reliable public mechanism for a Markdown file to switch the already-running main thread model on every surface. Smart Factory therefore uses truthful routing:

- **Stay local** when the lead is already sufficient or handoff overhead dominates.
- **Routed leaf** when a bounded independent task benefits materially from an exact model/effort.
- **Fail open** when discovery/dispatch is unavailable.

The router reads the installed Codex model catalog rather than assuming that every account has every model. It prefers the local account-scoped `models_cache.json`, then the bundled catalog, and only then an online-capable refresh to avoid unnecessary routing latency.

When available, it prefers roles such as:
- Luna-class: economy/deterministic/high-volume.
- Terra-class: balanced everyday work.
- Sol-class: difficult professional/cross-module work.
- Astra-class: hardest/high-ambiguity/high-consequence work.

Use `SMART_CODEX.cmd "task"` to start a new automatically routed CLI job.

## Old and new projects

The global Core applies to **all** Codex projects immediately after a fresh session because it lives in the global instruction layer.

The registry additionally:
- scans surviving session and archived/history JSONL for old CWDs;
- profiles still-existing project roots;
- watches new Codex sessions for new project CWDs.

It never executes session JSONL.

## Why project AGENTS files are not rewritten

OpenAI Codex loads global instructions and then project instructions. Project AGENTS content has a cumulative `project_doc_max_bytes` budget (32 KiB by default), while the global Codex-home instruction provider is separate. Copying a large global Core into each project would duplicate context and can starve nested project rules.

Smart Factory therefore leaves repository instructions under repository ownership.

## Files

- `src/CORE_AGENTS.md` — the complete always-on brain.
- `INSTALL.ps1` — installer/repair/uninstall.
- `CODEX_SMART_FACTORY.cmd` — Windows control panel.
- `SMART_CODEX.cmd` — exact auto-routed `codex exec`.
- `src/router/` — live-catalog model/reasoning router.
- `src/runtime/` — history scan, watcher, profile, status, doctor, reports.
- `tests/` — isolated installer/router/static tests.
- `docs/` — architecture, safety, sources, publishing notes.

## Safety

Smart Factory:
- does not rewrite `config.toml`;
- does not read or copy credentials;
- does not execute rollout/session JSONL;
- does not silently install third-party plugins/proxies;
- records whether a user `AGENTS.override.md` existed before first install and backs up its original content;
- never rolls back or rewrites user `AGENTS.md`; uninstall removes a generated override when untouched, preserves user additions made while installed, and never rolls back `AGENTS.md`;
- uses workspace-write or read-only routed workers, never automatic danger-full-access.

## License

MIT. Free for personal and commercial use.

## Project philosophy

The goal is not "use fewer tokens at all costs." The goal is fewer wasted tokens and fewer rework loops by improving retrieval, context discipline, model allocation, implementation scope, and verification.
