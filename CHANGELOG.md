# Changelog

## 1.1.0 — 2026-09-15

Unified Mission Control:
- one workflow tying plan decomposition, task DAG, model routing, progress, discoveries, verification, quota guard, watcher, and resume together;
- durable `.codex-smart-factory/` mission memory;
- best model, effort, reason, dependencies, discovered-from task, and actual model used recorded per task;
- discovered blocker/required work becomes a dependency before unrelated edits;
- dependency blockers auto-unblock only after dependencies finish; manual blockers stay sticky;
- structured 5-hour/weekly quota telemetry when available plus conservative fallback;
- safe-stop and deterministic resume protocol;
- Mission regression tests.


## 1.0.0 — 2026-09-15

Initial public release:
- regression-hardened uninstall that never rolls back user `AGENTS.md` and preserves user override edits;
- update/reinstall preservation of pre-existing global instructions;
- safe preservation of user edits made during installation and fresh snapshotting across repeated install/uninstall cycles;
- cache-first model catalog routing to avoid unnecessary online catalog latency;
- single comprehensive always-on global Core;
- safe preservation of existing global Codex instructions;
- old/new project registry;
- rollout-backed boost verification;
- local live-catalog model/reasoning router;
- exact routed `codex exec` workers;
- token/routing reports;
- Windows watcher;
- isolated tests and GitHub CI.
