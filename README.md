# Astra AGI Harness for Codex — Codex Smart Factory

[![CI](https://github.com/abram7200/codex-smart-factory/actions/workflows/ci.yml/badge.svg)](https://github.com/abram7200/codex-smart-factory/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/abram7200/codex-smart-factory)](https://github.com/abram7200/codex-smart-factory/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A free, open-source, Windows-first **agent harness for OpenAI Codex**: persistent Mission Control, GPT-6 Astra-aware model routing, long-horizon task execution, durable resume/checkpoints, context/token discipline, automatic project discovery, quota-aware safe stops, and verification gates for the **Codex Windows app and Codex CLI**.

> **AGI harness, not an AGI claim.** This project does not unlock hidden capabilities or claim to turn Codex/Astra into AGI. It is an orchestration and context-engineering layer designed to use the capabilities Codex already exposes more reliably over long, multi-step work.

## Latest verified release

**v1.1.4** is the current verified Windows release.

A healthy installed session reports:

```text
BOOSTED: YES | SmartFactory=1.1.4 | GlobalCore=ON | SessionInjected=YES | Router=ON(balanced) | Mission=ON(none) | QuotaGuard=ON | Watcher=ON | ProjectRegistry=ON
```

`Mission=ON(none)` means Mission Control is installed and ready but there is no active long-running mission in the current project.

## Supported surfaces

| Surface | Support |
|---|---|
| Codex Windows app | ✅ Primary target |
| Codex CLI on Windows | ✅ Primary target |
| Projects used before installation | ✅ Discovered from surviving Codex session/history metadata |
| New Codex projects | ✅ Learned automatically from live session CWDs |
| Ordinary ChatGPT chat / ChatGPT Work | ❌ Out of scope for this build |

## Fastest install — one clean CMD

For normal Windows users, download **`ASTRA_AGI_HARNESS.cmd`** from the latest GitHub Release and double-click it.

The one-file installer:

```text
one CMD
  ↓
resolve PowerShell safely
  ↓
download the pinned version to TEMP
  ↓
verify VERSION + Core + PowerShell precheck
  ↓
install/update into ~/.codex/smart-factory
  ↓
preserve user AGENTS + persistent state
  ↓
discover old projects + start watcher + router
  ↓
doctor/status
  ↓
remove temporary package
```

Nothing needs to remain beside the downloaded CMD. The actual runtime is installed under `%CODEX_HOME%\smart-factory` (normally `%USERPROFILE%\.codex\smart-factory`).

### Source checkout alternative

Developers can clone/download the repository and double-click the single root launcher:

```text
CODEX_SMART_FACTORY.cmd
```

There is no second root CMD and no large menu.

Optional advanced commands are available through the same launcher:

```bat
CODEX_SMART_FACTORY.cmd status
CODEX_SMART_FACTORY.cmd doctor
CODEX_SMART_FACTORY.cmd repair
CODEX_SMART_FACTORY.cmd task "your task"
CODEX_SMART_FACTORY.cmd profile balanced
CODEX_SMART_FACTORY.cmd uninstall
```

After a fresh install/Core update, restart Codex once and ask:

```text
Check if you are boosted or no?
```

The answer is evidence-backed: Smart Factory checks installation state, session injection, router, watcher heartbeat/PID, Mission runtime, quota guard, and project registry rather than replying from memory alone.

## Unified Mission Control

For non-trivial plans, multi-file changes, uncertain debugging jobs, or long-running work, Smart Factory uses one integrated state machine rather than unrelated skills:

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

Durable project state is stored in:

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

Every task records its stable ID, status, why it exists, dependencies, relations, discovered-from task, scope, acceptance criteria, verification, risk, **best model**, reasoning effort, **why that model**, and **model actually used**.

### Unexpected work becomes part of the graph

Newly discovered work is registered before unrelated implementation as one of:

- `blocker` — must be resolved before the parent continues;
- `required` — correctness/completion dependency;
- `related` — connected but non-blocking;
- `follow-up` — useful later;
- `out-of-scope` — recorded without silently expanding execution.

Dependency-created blockers auto-unblock only after their dependencies finish. Manual blockers remain blocked until explicitly resolved.

### Deterministic resume

`RESUME-FROM-HERE.md` is the recovery entrypoint after a crash, Codex app close, context compaction, usage pause, or new session. It records the mission, active/next task, quota snapshot, Git snapshot, exact next action, and recovery protocol so Codex does not rebuild the plan from memory.

## GPT-6 Astra-aware smart model routing

Smart Factory reads the installed Codex model catalog instead of assuming every account exposes every model.

| Work shape | Preferred class when available |
|---|---|
| deterministic lookup, formatting, bounded mechanical edit | Luna / economy |
| everyday implementation and moderate debugging | Terra / balanced |
| difficult cross-module or subtle debugging | Sol / strong |
| architecture, high ambiguity, high consequence, security/data-risk decisions | GPT-6 Astra / frontier |

Reasoning effort is selected separately. The router applies a **benefit gate**, so tiny tasks stay local when delegation overhead would cost more than it saves. User-selected model/effort always wins, and Smart Factory never auto-selects Ultra.

## Long-horizon usage, credits, and durability

Smart Factory **does not impose its own usage ban**. v1.1.4 changes quota handling so that low/exhausted included usage triggers a durable checkpoint, not a local STOP.

- 5-hour / weekly pressure → checkpoint mission state;
- `ordinaryUsageAllowed=false` / rate-limit telemetry → checkpoint, then let Codex decide whether an authorized flexible/credit-backed route is available;
- telemetry unavailable → periodic durability checkpoints only;
- Smart Factory never claims it can bypass a real server-side account limit.

This matters for users who have purchased credits: the harness should not block work merely because included usage reached a threshold. The Codex platform remains the authority on whether execution can continue and how it is billed.

## Context and token discipline

The Core optimizes **useful evidence per token**, not brevity at the expense of correctness:

- exact file/symbol/error before broad scans;
- targeted search and structured filtering before repository dumps;
- focused spans for large files;
- bounded terminal/log output;
- Git summary-first, then focused diff;
- reuse trustworthy unchanged context;
- no orchestration ceremony for tiny tasks;
- verification proportional to failure cost.

## Full always-on Core

`src/CORE_AGENTS.md` is the authoritative operating brain. The installer composes the full Core into global Codex `AGENTS.override.md`, so essential behavior is present from session start instead of relying on a tiny trigger that may or may not load another file later.

Project-owned `AGENTS.md` and `AGENTS.override.md` remain project-owned. Existing global user instructions are preserved across install/update/uninstall.

## Old and new projects

The global Core applies to every fresh Codex session after installation. The registry/watch layer additionally:

- scans surviving Codex session/history JSONL for old CWDs;
- profiles project roots that still exist;
- observes new Codex sessions for new project CWDs;
- never executes session/history JSONL as code.

## v1.1.4 credit-compatible quota fix

v1.1.4 removes Smart Factory's self-imposed STOP behavior at 5-hour/weekly thresholds. These signals now create checkpoints while leaving execution permission to Codex and any authorized flexible/credit-backed usage path exposed by the platform.

The v1.1.3 watcher reliability fix remains included.

### v1.1.3 watcher reliability fix

v1.1.3 fixes a false `Watcher=STALE` report that could appear even after startup verification succeeded. Watcher, installer, and status now use the same UTC heartbeat clock, and status requires **both a live watcher PID and a fresh heartbeat** before reporting `Watcher=ON`.

The Windows regression suite explicitly verifies watcher startup, heartbeat freshness, `Watcher=ON` status, and clean shutdown.

## Safety and non-goals

Smart Factory:

- does not rewrite `config.toml` merely to force behavior;
- does not read/copy credentials;
- does not execute rollout/session JSONL;
- does not silently install third-party proxies/plugins;
- does not auto-enable `danger-full-access`;
- does not claim model routing is a hidden AGI switch;
- does not claim guaranteed token savings or autonomous correctness.

## Release integrity

Every push to `main` runs Windows CI: single-root-CMD check, CMD self-test, PowerShell parser/precheck, regression tests, verified ZIP build, and SHA-256 generation. A versioned GitHub Release is published only after those gates pass.

Release assets include:

- `ASTRA_AGI_HARNESS.cmd` — one-file Windows installer/updater;
- `Astra-AGI-Harness-Codex-Smart-Factory-vX.Y.Z.zip` — verified source package;
- matching `.sha256` checksum.

## Designed for people searching for

OpenAI Codex, Codex Windows app, Codex CLI, GPT-6 Astra, Astra coding agent, AGI agent harness, autonomous coding agents, long-horizon coding, multi-agent orchestration, model routing, task graphs, context engineering, token efficiency, checkpoint/resume, durable agent memory, and AI software-engineering workflows.

See [`docs/AGI-HARNESS.md`](docs/AGI-HARNESS.md), [`docs/WINDOWS-CODEX.md`](docs/WINDOWS-CODEX.md), and [`docs/RELEASE_v1.1.4.md`](docs/RELEASE_v1.1.4.md).

## License

MIT. Free for personal and commercial use.

## Project philosophy

The goal is not “use fewer tokens at all costs.” The goal is **more completed, verified work per unit of context and user attention** through better retrieval, durable task state, model allocation, implementation scope, recovery, and verification.
