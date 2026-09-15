# Astra AGI Harness for Codex — Codex Smart Factory

[![CI](https://github.com/abram7200/codex-smart-factory/actions/workflows/ci.yml/badge.svg)](https://github.com/abram7200/codex-smart-factory/actions/workflows/ci.yml)

A free, open-source, Windows-first **agent harness for OpenAI Codex**: persistent Mission Control, GPT-6 Astra-aware model routing, long-horizon task execution, durable resume/checkpoints, context/token discipline, project discovery, and verification gates for the **Codex Windows app and Codex CLI**.

> **AGI harness, not an AGI claim.** This project does not unlock hidden model capabilities or claim to turn Codex/Astra into AGI. It is an orchestration and context-engineering layer designed to use the capabilities Codex already exposes more reliably over long, multi-step work.

## Supported surfaces

| Surface | Support |
|---|---|
| Codex Windows app | ✅ Primary target |
| Codex CLI on Windows | ✅ Primary target |
| Codex projects used before installation | ✅ Discovered from surviving Codex session/history metadata |
| New Codex projects | ✅ Learned automatically from live session CWDs |
| Ordinary ChatGPT chat / ChatGPT Work | ❌ Out of scope for this build |

## One smart Windows entrypoint

There is now **one user-facing CMD only**:

```text
CODEX_SMART_FACTORY.cmd
```

Double-click it with no arguments. There is no large menu and no second launcher.

It automatically:

```text
resolve PowerShell host
      ↓
precheck package
      ↓
install OR update the full Core
      ↓
preserve existing AGENTS rules
      ↓
discover old/current Codex projects
      ↓
initialize model router
      ↓
start/restart watcher
      ↓
run status + doctor
      ↓
READY
```

The launcher does **not** rely on `powershell.exe` being present in `PATH`. It checks the absolute Windows PowerShell System32/Sysnative locations first, then PowerShell 7, then PATH fallbacks.

### Optional advanced commands

Normal users do not need these, but the same single CMD supports them:

```bat
CODEX_SMART_FACTORY.cmd status
CODEX_SMART_FACTORY.cmd doctor
CODEX_SMART_FACTORY.cmd repair
CODEX_SMART_FACTORY.cmd task "your task"
CODEX_SMART_FACTORY.cmd profile balanced
CODEX_SMART_FACTORY.cmd uninstall
```

No separate `SMART_CODEX.cmd` exists anymore.

## Install — Windows

1. Download or clone the repository.
2. Double-click **`CODEX_SMART_FACTORY.cmd`**.
3. Let the automatic setup finish.
4. Restart Codex once if this is a fresh install or Core update.
5. In a fresh Codex session ask:

```text
Check if you are boosted or no?
```

A healthy session reports a status similar to:

```text
BOOSTED: YES | SmartFactory=1.1.1 | GlobalCore=ON | SessionInjected=YES | Router=ON(balanced) | Mission=ON(...) | QuotaGuard=ON | Watcher=ON | ProjectRegistry=ON
```

If the Core is installed but the current Codex thread started before installation, the status reports `PENDING_RESTART` instead of pretending the Core was injected.

## Why this exists

Modern coding agents can work for hours, touch many repositories, use multiple models, and accumulate a lot of context. The hard part is often **managing the work**:

- keep a long plan executable after context compaction or app restart;
- avoid wasting context on huge logs and irrelevant files;
- choose a cheaper model when it is enough and escalate when failure cost is high;
- record newly discovered bugs instead of silently expanding scope;
- verify work before marking tasks done;
- checkpoint before usage/session pressure can strand an unfinished task;
- resume deterministically instead of planning from zero.

Smart Factory combines those behaviors into **one workflow/state machine**, not unrelated skills.

## Full always-on Core

`src/CORE_AGENTS.md` is the authoritative operating brain. The installer composes the full Core into the global Codex `AGENTS.override.md`, so essential behavior is present from session start instead of depending on a tiny lazy-loaded trigger.

The installer deliberately does **not** replace project-owned `AGENTS.md` or `AGENTS.override.md` files.

## Unified Mission Control

For a non-trivial plan, multi-file change, uncertain debugging job, or long-running task, Smart Factory creates durable project working memory:

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
Plan / Task DAG
    ↓
Choose model + reasoning per task
    ↓
Quota/session preflight
    ↓
Execute one bounded task
    ↓
Register unexpected bugs/work
    ↓
Verify acceptance criteria
    ↓
Checkpoint durable state
    ↓
Next task / safe stop / resume
```

Every task records its stable ID, status, why it exists, dependencies, relations, discovered-from task, scope, acceptance criteria, verification, risk, **best model**, reasoning effort, **why that model**, and **model actually used**.

### Discovered work becomes part of the graph

Unexpected work is not silently absorbed. It becomes a linked task classified as:

- `blocker` — must be resolved before the parent continues;
- `required` — necessary dependency for correctness/completion;
- `related` — connected but does not block current work;
- `follow-up` — useful later;
- `out-of-scope` — recorded without automatically expanding execution.

Dependency-created blockers auto-unblock only after their dependencies finish. Manual blockers remain blocked until explicitly resolved.

### Deterministic resume

`RESUME-FROM-HERE.md` is the recovery entrypoint after a crash, Codex app close, context compaction, usage pause, or a new session. It stores the mission, active/next task, quota snapshot, Git snapshot, exact next action, and recovery protocol.

## GPT-6 Astra-aware smart model routing

Smart Factory reads the installed Codex model catalog rather than assuming every account exposes every model.

Typical roles when available:

| Work shape | Preferred class |
|---|---|
| deterministic lookup, formatting, bounded mechanical edit | Luna-class / economy |
| everyday implementation and moderate debugging | Terra-class / balanced |
| difficult cross-module or subtle debugging | Sol-class / strong |
| architecture, high ambiguity, high consequence, security/data-risk decisions | GPT-6 Astra / frontier |

The router also chooses reasoning effort and uses a **benefit gate**: tiny tasks stay local when delegation overhead would cost more than it saves.

To launch a new routed CLI task through the same single entrypoint:

```bat
CODEX_SMART_FACTORY.cmd task "Fix this production race condition and verify it"
```

Profiles are also controlled through the same CMD:

```bat
CODEX_SMART_FACTORY.cmd profile token-saver
CODEX_SMART_FACTORY.cmd profile balanced
CODEX_SMART_FACTORY.cmd profile max-quality
```

Balanced is the default recommendation. Smart Factory never auto-selects Ultra.

## Long-horizon and 5-hour safety

Mission Control checks Codex rate-limit telemetry when available. Default policy:

- 5-hour remaining ≤ 15% → safe stop before new work;
- weekly remaining ≤ 10% → safe stop;
- strong/frontier or high/xhigh/max task with <25% of the 5-hour window remaining → do not start it;
- rising quota pressure → checkpoint before more work;
- telemetry unavailable → conservative elapsed-session checkpoints/stops.

This project does **not** bypass Codex limits. The goal is to checkpoint before a cutoff can strand a large unfinished step.

## Context and token discipline

The Core optimizes **useful evidence per token**, not brevity at the expense of correctness:

- exact file/symbol/error before broad scans;
- targeted search/structured filtering before repository dumps;
- focused spans for large files;
- bounded terminal/log output;
- Git summary-first, then focused diff;
- reuse trustworthy unchanged context;
- no orchestration overhead for tiny tasks;
- verification proportional to failure cost.

## Old and new projects

The global Core applies to every fresh Codex session after installation. The registry/watch layer additionally:

- scans surviving Codex session/history JSONL for old CWDs;
- profiles project roots that still exist;
- observes new Codex sessions for new project CWDs;
- never executes session/history JSONL as code.

## Existing AGENTS rules are preserved

Smart Factory is conservative around user instructions:

- existing global Codex instructions are composed with the Core;
- project `AGENTS.md` and `AGENTS.override.md` stay project-owned;
- reinstall/update preserves existing global rules;
- user edits made while Smart Factory is installed survive uninstall;
- uninstall refuses to guess if its original-state snapshot is missing.

## Self-check

The phrase:

```text
Check if you are boosted or no?
```

is part of the Core contract. Codex should answer from installation/session evidence rather than memory alone.

You can also check from Windows:

```bat
CODEX_SMART_FACTORY.cmd status
```

## Files

- `CODEX_SMART_FACTORY.cmd` — **the only Windows user entrypoint**; automatic setup/update plus optional subcommands.
- `INSTALL.ps1` — installer/update/repair/uninstall/watcher control.
- `src/CORE_AGENTS.md` — complete always-on operating brain.
- `src/mission/` — task DAG, durable Markdown state, quota guard, resume/checkpoint workflow.
- `src/router/` — live-catalog model/reasoning router and bounded worker dispatch.
- `src/runtime/` — history scan, watcher, project registry/profile, status, doctor, reports, backups.
- `tests/` — Windows PowerShell regression tests.
- `docs/` — architecture, Windows usage, safety, sources, and AGI-harness positioning.

## Safety and non-goals

Smart Factory:

- does not rewrite `config.toml` merely to force behavior;
- does not read/copy credentials;
- does not execute rollout/session JSONL;
- does not silently install third-party proxies/plugins;
- does not auto-enable `danger-full-access`;
- does not claim model routing is a hidden AGI switch;
- does not claim guaranteed token savings or autonomous correctness.

## Designed for people searching for

OpenAI Codex, Codex Windows app, Codex CLI, GPT-6 Astra, Astra coding agent, AGI agent harness, autonomous coding agents, long-horizon coding, multi-agent orchestration, model routing, task graphs, context engineering, token efficiency, checkpoint/resume, durable agent memory, and AI software-engineering workflows.

See [`docs/AGI-HARNESS.md`](docs/AGI-HARNESS.md) and [`docs/WINDOWS-CODEX.md`](docs/WINDOWS-CODEX.md).

## License

MIT. Free for personal and commercial use.

## Project philosophy

The goal is not “use fewer tokens at all costs.” The goal is **more completed, verified work per unit of context and user attention** through better retrieval, durable task state, model allocation, implementation scope, recovery, and verification.
