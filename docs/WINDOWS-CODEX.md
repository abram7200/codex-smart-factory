# Codex on Windows: App + CLI

Codex Smart Factory v1.1.1 focuses on **Codex for Windows**: the Codex desktop app and Codex CLI.

## One Codex operating layer

The package installs its Core under the user's Codex home and composes it into the global Codex `AGENTS.override.md`. Repository-owned `AGENTS.md` / `AGENTS.override.md` files are not replaced.

```text
                Global Codex Core
                      │
          ┌───────────┴───────────┐
          │                       │
   Codex Windows app         Codex CLI
          │                       │
          └──── same projects ────┘
                      │
              Mission Control
                      │
        task DAG / route / resume
```

Ordinary ChatGPT chat is out of scope for this release.

## One smart Windows launcher

There is only one root CMD:

```text
CODEX_SMART_FACTORY.cmd
```

Double-click it. There is no large interactive menu and no second task launcher.

With no arguments it automatically:

1. resolves a usable PowerShell executable without relying on PATH;
2. prechecks every PowerShell script and validates the Core;
3. installs or updates the runtime;
4. preserves existing global instructions;
5. scans surviving Codex history/session metadata for old projects;
6. initializes the router;
7. starts/restarts the project watcher;
8. prints runtime status;
9. runs the final doctor check.

PowerShell discovery order is intentionally robust for Windows machines with broken or customized PATH values:

1. `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`
2. `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe`
3. `%ProgramFiles%\PowerShell\7\pwsh.exe`
4. `pwsh.exe` / `powershell.exe` from PATH as final fallbacks

Restart Codex once after a fresh install or Core update so a new app/CLI thread starts with the new global instruction layer.

## Verify from Codex itself

In a fresh Codex thread ask:

```text
Check if you are boosted or no?
```

Important fields include:

- `GlobalCore` — global composed Core exists;
- `SessionInjected` — current rollout evidence contains the Core marker;
- `Router` — model-router runtime/profile;
- `Mission` — Mission Control runtime/current mission state;
- `QuotaGuard` — long-horizon usage guard runtime;
- `Watcher` — background watcher heartbeat;
- `ProjectRegistry` — current project was observed/registered.

A thread opened before installation can correctly report `PENDING_RESTART`.

## Optional advanced commands — same CMD

The normal workflow is just double-click. Advanced users can use the same entrypoint:

```cmd
CODEX_SMART_FACTORY.cmd status
CODEX_SMART_FACTORY.cmd doctor
CODEX_SMART_FACTORY.cmd repair
CODEX_SMART_FACTORY.cmd task "Design and implement the requested change, including verification"
CODEX_SMART_FACTORY.cmd profile token-saver
CODEX_SMART_FACTORY.cmd profile balanced
CODEX_SMART_FACTORY.cmd profile max-quality
CODEX_SMART_FACTORY.cmd uninstall
```

`balanced` is the recommended routing profile.

## Existing projects

You do not need to open every old repository and modify it manually.

The history scanner reads surviving Codex rollout/session metadata as untrusted data, extracts working directories, resolves still-existing project roots, and profiles/registers them centrally. It never executes rollout content.

The global Core already applies to fresh sessions even when a project has not yet been observed by the registry.

## New projects

The watcher monitors new Codex session metadata, resolves project roots, and updates the central registry/profile automatically. New repositories do not require a separate Smart Factory installation.

## Existing AGENTS files

The installer does not spray the large Core into repositories.

Project `AGENTS.md` and `AGENTS.override.md` remain user/project-owned. The Core is global; project-specific rules stay local. This prevents destructive replacement and unnecessary context duplication.

## Mission Control in either Codex surface

For non-trivial work the same Mission runtime persists state under:

```text
<project>\.codex-smart-factory\
```

The state does not depend on whether the work started from the desktop app or CLI. On resume, Codex uses `RESUME-FROM-HERE.md`, reconciles repository state, and continues the recorded task instead of rebuilding the plan from memory.

## Model routing

The router discovers the local Codex model catalog and tolerates partial catalog schemas. When available, task classes map roughly from Luna → Terra → Sol → GPT-6 Astra as ambiguity, coupling, failure cost, and verification burden rise.

The best model, effort, reason, and actual model used are stored in task state.

## 5-hour / weekly guard

Mission Control reads Codex rate-limit telemetry when available. It does not bypass limits. It uses the telemetry to decide whether to continue, checkpoint, refuse a large new task, or safe-stop with a deterministic resume point.

If structured telemetry is unavailable, conservative elapsed-session safeguards are used.

## Tested platform

GitHub Actions runs on Windows and verifies:

- exactly one root CMD entrypoint exists;
- `CODEX_SMART_FACTORY.cmd --self-test` can resolve and launch PowerShell;
- PowerShell parsing/precheck;
- router regressions;
- installer/update/uninstall preservation;
- Mission Control state transitions and safe-stop behavior;
- verified release ZIP + SHA-256 generation on green `main` pushes.
