# Astra AGI Harness for Codex — v1.1.4

Windows-first release for **Codex Windows app + Codex CLI**.

## Main fix: Smart Factory no longer blocks paid/flexible continuation

A real-world v1.1.3 session exposed a design bug: Mission Control treated exhausted included 5-hour/weekly usage as a local **STOP**, even when the account showed purchased credits.

v1.1.4 changes that policy:

- exhausted/low included usage => **CHECKPOINT**, not Smart Factory STOP;
- `ordinaryUsageAllowed=false` or backend rate-limit telemetry => checkpoint immediately, then let Codex/the platform determine whether authorized flexible or credit-backed execution can continue;
- heavy tasks near a quota boundary => checkpoint first, but Smart Factory does not refuse them solely because of a local threshold;
- unavailable quota telemetry => periodic durability checkpoints, never a wall-clock usage ban;
- Mission state stays active after quota-pressure checkpoint.

Smart Factory does **not** bypass real OpenAI server-side account/rate limits. It simply stops adding an extra local restriction on top of the platform.

## Still included

- Global always-on Core with preservation of existing AGENTS rules.
- Unified Mission Control and task DAG.
- Per-task model/reasoning routing: Astra / Sol / Terra / Luna when available.
- Automatic discovered bugs/tasks and dependency links.
- PROGRESS / FINDINGS / RESUME-FROM-HERE durable state.
- Watcher + old/new project registry.
- v1.1.3 UTC heartbeat/PID watcher reliability fix.
- One-file Windows installer.
- Windows CI regression suite.

## Expected healthy state

```text
BOOSTED: YES | SmartFactory=1.1.4 | GlobalCore=ON | SessionInjected=YES | Router=ON(balanced) | Mission=ON(none) | QuotaGuard=ON | Watcher=ON | ProjectRegistry=ON
```

> “AGI harness” describes orchestration/context engineering around Codex capabilities. This package does not claim to create AGI or bypass platform-enforced usage limits.
