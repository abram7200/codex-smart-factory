# Astra AGI Harness for Codex — Codex Smart Factory

[![CI](https://github.com/abram7200/codex-smart-factory/actions/workflows/ci.yml/badge.svg)](https://github.com/abram7200/codex-smart-factory/actions/workflows/ci.yml)

A free, open-source, Windows-first **agent harness for OpenAI Codex**: persistent Mission Control, GPT-6 Astra-aware model routing, long-horizon task execution, durable resume/checkpoints, context/token discipline, project discovery, and verification gates for the **Codex Windows app and Codex CLI**.

> **AGI harness, not an AGI claim.** This project does not unlock hidden model capabilities or claim to turn Codex/Astra into AGI. It is an orchestration and context-engineering layer designed to use the capabilities Codex already exposes more reliably over long, multi-step work.

## Supported surfaces

| Surface | Support |
|---|---|
| Codex Windows app | ✅ Primary target |
| Codex CLI on Windows | ✅ Primary target |
| Codex projects already used before installation | ✅ Discovered from surviving Codex history/session metadata |
| New Codex projects | ✅ Learned automatically from live session CWDs |
| Ordinary ChatGPT chat / ChatGPT Work | ❌ Out of scope for this build |

The Windows app and CLI are treated as two front ends to the same Codex home/project instruction model. Smart Factory installs its full Core globally and leaves repository-owned instructions under repository control.

## Why this exists

Modern coding agents can work for hours, use multiple models/agents, and touch large repositories. The hard part is often not raw model intelligence; it is **managing the work**:

- keep a long plan executable after context compaction or app restart;
- avoid wasting context on huge logs and irrelevant files;
- choose a cheaper model when it is enough and escalate when failure cost is high;
- record newly discovered bugs instead of silently expanding scope;
- verify work before marking tasks done;
- checkpoint before usage/session pressure can strand an unfinished task;
- resume deterministically rather than starting the reasoning over.

Smart Factory combines those behaviors into **one workflow/state machine**, not a pile of unrelated skills.

## What makes this build different

The essential behavior is **not hidden behind a tiny trigger file**.

`src/CORE_AGENTS.md` is the single authoritative always-on operating brain. The installer composes that **full Core** into the global Codex `AGENTS.override.md`, so the operating rules are present from session start. Runtime scripts automate project discovery, Mission Control, quota checks, model routing, health checks, and reports, but core correctness does not depend on Codex deciding to open another Markdown reference later.

This design deliberately does **not** copy the Core into every repository. Existing project `AGENTS.md` / `AGENTS.override.md` files remain user-owned and project-specific.

## Features

- Full always-on global Core: retrieval, context management, debugging, implementation, verification, delegation, safety, communication, and routing discipline.
- Preserves pre-existing global Codex instructions across install, reinstall/update, repair, and uninstall.
- Does **not** overwrite repository `AGENTS.md` / `AGENTS.override.md`.
- Finds old projects from surviving Codex session/history metadata and learns new projects automatically.
- Central project registry/profile state without requiring source-repository pollution.
- Unified Mission Control: plan → task DAG → route → preflight → execute → discover → verify → checkpoint → next.
- Durable `TASKS.md`, per-task cards, progress/findings, machine state, and `RESUME-FROM-HERE.md`.
- Every task records best model, effort, model reason, dependencies, relations, discovery parent, acceptance/verification, and actual model used.
- Discovered work becomes `blocker`, `required`, `related`, `follow-up`, or `out-of-scope`; blocker/required work becomes a real graph dependency.
- Live Codex model-catalog discovery with cache/bundled fallbacks and partial-schema tolerance.
- Benefit-gated routed `codex exec` workers instead of pretending every active main thread can be silently model-switched.
- Luna / Terra / Sol / GPT-6 Astra role selection when those models are available to the account.
- Token-saver / balanced / max-quality routing profiles; no automatic Ultra; hidden/internal model exclusion.
- 5-hour/weekly usage guard using Codex rate-limit telemetry when available, with conservative time-based fallback.
- Rollout-backed **"Check if you are boosted or no?"** self-check.
- Token-usage and routing-decision reports.
- Backup/repair/uninstall safety and Windows GitHub Actions tests.
- No proxy, no credential scraping, no automatic `danger-full-access`.

## Install — Windows

1. Download or clone this repository.
2. Double-click `CODEX_SMART_FACTORY.cmd`.
3. Choose **1 — FULL INSTALL / UPDATE**.
4. Restart Codex once (Windows app and/or CLI sessions opened before install cannot retroactively contain the new global Core).
5. In a fresh Codex session ask:

```text
Check if you are boosted or no?
```

A fully active session should report a line similar to:

```text
BOOSTED: YES | SmartFactory=1.1.0 | GlobalCore=ON | SessionInjected=YES | Router=ON(balanced) | Mission=ON(...) | QuotaGuard=ON | Watcher=ON | ProjectRegistry=ON
```

If installation is correct but the current thread predates installation, status reports `PENDING_RESTART` rather than claiming injection happened.

You can also run directly from PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\INSTALL.ps1 install
```

## Unified Mission Control

For a non-trivial plan, multi-file change, uncertain debugging job, or long-running task, Smart Factory creates durable local working memory:

```text
.codex-smart-factory/
├── MISSION.md
├── TASKS.md
├── tasks/
│   ├── T001.md
│   ├── T002.md
│   └── ...
├── PROGRESS.md
├── FINDINGS.md
├── RESUME-FROM-HERE.md
└── mission.json
```

The integrated loop is:

```text
Understand goal
    ↓
Plan / task DAG
    ↓
Choose model + reasoning per task
    ↓
Quota / session preflight
    ↓
Execute one bounded task
    ↓
Register unexpected bugs/work before scope expands
    ↓
Verify acceptance criteria
    ↓
Checkpoint durable state
    ↓
Next ready task / safe stop / resume
```

`RESUME-FROM-HERE.md` is the deterministic recovery entrypoint after a crash, Codex app close, context compaction, usage pause, or a new session. It records the mission, active/next task, quota snapshot, Git snapshot, exact next action, and recovery protocol.

### Discovered work is part of the graph

Unexpected work is not silently absorbed. Codex records it as a new task and links it back to the task where it was discovered.

- `blocker` — must be resolved before the parent can continue;
- `required` — necessary dependency for correctness/completion;
- `related` — connected but does not block the current task;
- `follow-up` — useful later, not required for current completion;
- `out-of-scope` — recorded but not automatically pulled into execution.

Dependency-created blockers auto-unblock only after dependencies are complete. A manually blocked task stays blocked until explicitly resolved.

## GPT-6 Astra-aware smart model routing

Smart Factory does not hard-code one model for all work and does not assume every account exposes every model. It reads the installed Codex model catalog and routes by task cost, ambiguity, coupling, risk, and verification burden.

Typical roles when available:

| Work shape | Preferred class |
|---|---|
| deterministic lookup, formatting, bounded mechanical edit | Luna-class / economy |
| everyday implementation and moderate debugging | Terra-class / balanced |
| difficult professional, cross-module, subtle debugging | Sol-class / strong |
| architecture, high ambiguity, high consequence, security/data-risk decisions | GPT-6 Astra / frontier |

The router also selects reasoning effort. It stays local when delegation overhead would cost more than it saves and dispatches a bounded exact-model leaf only when benefit is clear.

Use:

```text
SMART_CODEX.cmd "your task"
```

for a new automatically routed CLI job.

## Long-horizon and 5-hour safety

Mission Control checks Codex rate-limit telemetry through the local app-server when available. Default policy:

- 5-hour remaining ≤ 15% → safe stop before new work;
- weekly remaining ≤ 10% → safe stop;
- strong/frontier or high/xhigh/max task with <25% of the 5-hour window remaining → do not start it;
- rising quota pressure → checkpoint before more work;
- telemetry unavailable → conservative elapsed-session checkpoints/stops.

The project does **not** bypass Codex limits. The safety design reduces lost work by making durable checkpoints *before* a cutoff can strand a large unfinished step.

## Context and token discipline

The Core optimizes **useful evidence per token**, not brevity for its own sake:

- exact file/symbol/error before broad scans;
- targeted `rg`/structured filtering before repository dumps;
- focused spans for large files;
- bounded terminal/log output;
- Git summary-first (`status`, `--stat`, `--name-only`, then focused diff);
- reuse trustworthy unchanged context;
- do not add orchestration overhead to tiny tasks;
- verification is proportional to failure cost, never skipped merely to save tokens.

## Old and new projects

The global Core applies to every fresh Codex session after installation. The background registry/watch layer additionally:

- scans surviving Codex session/history JSONL for old CWDs;
- profiles project roots that still exist;
- watches new Codex sessions for new project CWDs;
- never executes session/history JSONL as code.

## Existing AGENTS rules are preserved

Smart Factory is intentionally conservative around user instructions:

- pre-existing global Codex instructions are composed with the Core;
- project `AGENTS.md` and project `AGENTS.override.md` are never replaced by the installer;
- reinstall/update preserves the user's original global rules;
- user edits made while Smart Factory is installed survive uninstall;
- uninstall refuses to guess if its original-state snapshot is missing.

## Self-check, repair, and reports

Use `CODEX_SMART_FACTORY.cmd` for the Windows control panel or `INSTALL.ps1` actions for scripting. Supported operations include install/update, repair, doctor, status, old-project scan, usage report, project registry, router status/report, watcher start/stop, and uninstall.

The phrase:

```text
Check if you are boosted or no?
```

is intentionally part of the Core contract. Codex should answer from actual installation/session evidence, including whether the global Core was present in the current rollout.

## Files

- `src/CORE_AGENTS.md` — complete always-on operating brain.
- `src/mission/` — task DAG, durable Markdown state, quota guard, resume/checkpoint workflow.
- `src/router/` — live-catalog model/reasoning router and bounded worker dispatch.
- `src/runtime/` — history scan, watcher, project profile/registry, status, doctor, reports, backup helpers.
- `INSTALL.ps1` — installer, update, repair, uninstall, watcher control.
- `CODEX_SMART_FACTORY.cmd` — Windows control panel.
- `SMART_CODEX.cmd` — automatically routed CLI entrypoint.
- `tests/` — Windows PowerShell regression tests.
- `docs/` — architecture, Windows usage, safety, sources, and AGI-harness positioning.

## Safety and non-goals

Smart Factory:

- does not rewrite `config.toml` just to force behavior;
- does not read/copy credentials;
- does not execute rollout/session JSONL;
- does not silently install third-party proxies/plugins;
- does not auto-enable `danger-full-access`;
- does not claim that model routing is a hidden AGI switch;
- does not claim guaranteed token savings or guaranteed autonomous correctness.

It **does** try to reduce wasted context, repeated work, unsafe late-session starts, scope drift, and weak verification.

## Designed for people searching for

OpenAI Codex, Codex Windows app, Codex CLI, GPT-6 Astra, Astra coding agent, AGI agent harness, autonomous coding agents, long-horizon coding, multi-agent orchestration, model routing, task graphs, context engineering, token efficiency, checkpoint/resume, durable agent memory, and AI software-engineering workflows.

See [`docs/AGI-HARNESS.md`](docs/AGI-HARNESS.md) for the technical meaning of “AGI harness” in this project and [`docs/WINDOWS-CODEX.md`](docs/WINDOWS-CODEX.md) for the Windows App/CLI workflow.

## License

MIT. Free for personal and commercial use.

## Project philosophy

The goal is not “use fewer tokens at all costs.” The goal is **more completed, verified work per unit of context and user attention** by improving retrieval, durable task state, model allocation, implementation scope, recovery, and verification.