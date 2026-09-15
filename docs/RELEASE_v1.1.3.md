# Astra AGI Harness for Codex — v1.1.3

Windows-first release for **Codex Windows app + Codex CLI**.

## What is verified in this release

- Full global always-on Core with preservation of existing user/project `AGENTS` rules.
- Unified Mission Control: plan → task DAG → per-task model/effort → execution → verification → checkpoint/resume.
- Per-task best model, reasoning effort, reason, dependency links, discovered-from task, and actual model used.
- Discovered bugs/work are registered as blocker/required/related/follow-up/out-of-scope tasks instead of silently expanding scope.
- Durable `PROGRESS.md`, `FINDINGS.md`, task cards, machine state, and `RESUME-FROM-HERE.md`.
- GPT-6 Astra / Sol / Terra / Luna-aware routing from the live Codex model catalog when available.
- 5-hour / weekly quota-aware safe-stop behavior with conservative fallback when telemetry is unavailable.
- Old-project discovery plus automatic new-project watcher.
- One smart Windows entrypoint and a separate **single-file release bootstrapper** for users who want only one downloaded CMD.
- Existing installation upgrades in place while preserving persistent Smart Factory state.

## v1.1.3 reliability fix

This release fixes the false `Watcher=STALE` state seen after a successful watcher startup. Watcher, installer, and status now use the same UTC heartbeat clock, and status requires both a live watcher PID and a fresh heartbeat before reporting `Watcher=ON`.

The Windows regression suite now verifies that the watcher starts, the heartbeat remains fresh, `Status.ps1` reports `Watcher=ON`, and the watcher stops cleanly.

## Healthy final state

After installation/update and one Codex restart, the expected status is:

```text
BOOSTED: YES | SmartFactory=1.1.3 | GlobalCore=ON | SessionInjected=YES | Router=ON(balanced) | Mission=ON(none) | QuotaGuard=ON | Watcher=ON | ProjectRegistry=ON
```

`Mission=ON(none)` means Mission Control is installed and ready but no long-running mission is active in the current project.

## Install choices

### Simplest: one clean file

Download `ASTRA_AGI_HARNESS.cmd` from the release assets and double-click it. It downloads the pinned v1.1.3 source to a temporary directory, validates it, installs/updates safely, runs doctor/status, then removes the temporary package.

### Source checkout

Clone/download the repository and double-click `CODEX_SMART_FACTORY.cmd`.

## Scope

Primary targets are **Codex Windows app** and **Codex CLI on Windows**. Ordinary ChatGPT chat/Work is not part of this build.

> “AGI harness” describes orchestration/context engineering around Codex capabilities. This package does not claim to create AGI or unlock hidden model capabilities.
