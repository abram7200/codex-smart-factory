# Codex on Windows: App + CLI

Codex Smart Factory v1.1.0 is intentionally focused on **Codex for Windows**: the Codex desktop app and Codex CLI.

## One Codex operating layer

The package installs its Core under the user's Codex home and composes it into the global Codex `AGENTS.override.md`. Repository-owned `AGENTS.md` / `AGENTS.override.md` files are not replaced.

The practical model is:

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

The package does not target ordinary ChatGPT chat in this release.

## Install

From the repository folder, either double-click:

```text
CODEX_SMART_FACTORY.cmd
```

and choose **FULL INSTALL / UPDATE**, or run:

```powershell
powershell -ExecutionPolicy Bypass -File .\INSTALL.ps1 install
```

Installation performs the following as one operation:

1. parses every PowerShell script and validates the Core marker;
2. records the pre-install global-instruction state for safe uninstall;
3. copies the runtime into the Codex home;
4. composes the full Core with pre-existing global user instructions;
5. scans surviving Codex history/session metadata for old project CWDs;
6. initializes the model router;
7. installs/starts the project watcher unless `-NoAutostart` is supplied;
8. prints status.

Restart Codex after installation so a new app/CLI thread starts with the new global instruction layer.

## Verify from Codex itself

In a fresh Codex thread ask exactly:

```text
Check if you are boosted or no?
```

The Core tells Codex to report from actual runtime/session evidence. Important fields include:

- `GlobalCore` — the global composed Core exists;
- `SessionInjected` — current rollout evidence contains the Core marker;
- `Router` — model routing runtime and selected profile;
- `Mission` — Mission runtime/current mission state;
- `QuotaGuard` — long-horizon usage guard runtime;
- `Watcher` — background project watcher heartbeat;
- `ProjectRegistry` — current project was registered.

A thread opened before installation may correctly show `PENDING_RESTART`.

## Existing projects

You do not need to open every old repository and modify it manually.

`Scan-History.ps1` looks at surviving Codex rollout/session metadata, extracts project working directories, resolves project roots, and registers/profile them centrally. It treats those files only as data; it does not execute their contents.

The global Core already applies to fresh sessions even when a project is not in the registry. The registry supplies project observation/profiling rather than acting as the only injection path.

## New projects

The watcher monitors Codex session JSONL creation/changes, extracts working directories, resolves project roots, and updates the central registry/profile. This is why a new repo does not require a separate Smart Factory installation.

## Existing AGENTS files

The installer deliberately does not spray the large Core into repositories.

If a project already has instructions, Codex can still apply them as project-specific rules. The Smart Factory Core is global; project rules remain local. This avoids destroying user instructions and avoids duplicating the same large Core in every repository.

## Mission Control in either surface

For non-trivial work the same Mission runtime can persist state under:

```text
<project>\.codex-smart-factory\
```

The state is independent of whether the work was initiated from the desktop app or CLI. On resume, Codex reads `RESUME-FROM-HERE.md`, reconciles the Git state, reads only the active/next task card and relevant progress/findings tail, then continues.

## Model routing

The router discovers the model catalog from the local Codex environment. If model names/capabilities change or a particular account exposes a different subset, the router is designed to tolerate partial catalog schemas and choose among available models rather than requiring one hard-coded list.

When available, it maps task classes roughly to Luna → Terra → Sol → GPT-6 Astra as complexity/ambiguity/consequence rise. The selected model and effort are written into task state; actual model usage is also recorded.

## 5-hour / weekly guard

Mission Control asks the local Codex app-server for rate-limit telemetry when it can. The guard does not bypass or extend limits. It uses the information to decide whether to:

- continue;
- checkpoint before more work;
- refuse to start a large task;
- write a safe-stop/resume state.

If structured telemetry is unavailable, it falls back conservatively to continuous-session time.

## Useful control commands

From the package directory:

```powershell
.\INSTALL.ps1 status
.\INSTALL.ps1 doctor
.\INSTALL.ps1 repair
.\INSTALL.ps1 scan
.\INSTALL.ps1 projects
.\INSTALL.ps1 usage
.\INSTALL.ps1 router-status
.\INSTALL.ps1 router-report
.\INSTALL.ps1 start
.\INSTALL.ps1 stop
.\INSTALL.ps1 uninstall
```

Use `CODEX_SMART_FACTORY.cmd` if you prefer the clickable menu.

## Routed CLI entrypoint

For a new CLI task where you want Smart Factory to choose the route before starting:

```cmd
SMART_CODEX.cmd "Design and implement the requested change, including verification"
```

The routing layer stays conservative: cheap/local work remains cheap/local; high-risk or high-ambiguity work can escalate when a stronger model is available and the benefit justifies a worker.

## Tested platform

The repository CI runs on GitHub-hosted Windows and validates PowerShell parsing plus router, installer/uninstaller preservation, and Mission Control regressions. A green CI badge on the README is the release gate used for this Windows-first build.
