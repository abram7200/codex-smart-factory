# AGI Harness: what this project means (and does not mean)

## Short version

Codex Smart Factory uses **AGI harness** as an engineering description for a system that helps a capable general-purpose coding model operate over long, stateful, multi-step work with tools, durable memory, routing, verification, and recovery.

It does **not** claim to create AGI, unlock a hidden AGI mode, jailbreak GPT-6 Astra, or reveal model capabilities that OpenAI has not exposed.

## The harness idea

A strong model can still lose effectiveness when the surrounding workflow is weak. Long jobs accumulate stale context, duplicate evidence, scope drift, weak checkpoints, unfinished branches, or expensive model usage on trivial work. Smart Factory therefore treats the surrounding runtime as part of the intelligence of the overall system.

The integrated loop is:

```text
Understand
  ↓
Plan
  ↓
Build task/dependency graph
  ↓
Route model + reasoning
  ↓
Act with bounded scope
  ↓
Observe evidence
  ↓
Register new discoveries
  ↓
Verify
  ↓
Persist state
  ↓
Adapt / resume
```

That loop is the “harness”. It is designed to expose more of the practical usefulness of Codex/Astra by reducing avoidable failure modes around the model.

## Why GPT-6 Astra matters here

When GPT-6 Astra is available in the local Codex model catalog, Smart Factory treats it as a frontier option for work where stronger reasoning can materially reduce expected rework: architecture, high ambiguity, difficult root-cause analysis, security/data integrity, migrations, high-consequence decisions, or difficult integration/review.

Astra is **not** forced onto every task. Mechanical work may be better handled by an economy model; everyday implementation may be better handled by a balanced model. The router optimizes for expected total work to a verified result, not model prestige.

The installed model catalog remains the source of truth. If Astra is unavailable to the account/environment, the system routes to the best available alternative rather than fabricating availability.

## Durable cognition, not fake memory

Mission Control deliberately externalizes working state into project-local Markdown and JSON:

- `MISSION.md` — objective, success condition, constraints, current gate;
- `TASKS.md` — visible task DAG/checklist;
- `tasks/<ID>.md` — detailed task contract and model plan;
- `PROGRESS.md` — execution and verification history;
- `FINDINGS.md` — discoveries and decisions;
- `RESUME-FROM-HERE.md` — deterministic recovery point;
- `mission.json` — machine-readable state.

These files are not a claim of persistent model memory. They are explicit state the next Codex session can inspect and reconcile against the repository.

## Adaptation during work

A long plan is not frozen. If Codex discovers a bug, hidden dependency, missing test, or necessary edit, it must register that work before expanding implementation scope. The discovered task is linked to the task that exposed it and classified as:

- blocker;
- required;
- related;
- follow-up;
- out-of-scope.

This makes adaptation auditable instead of turning the original plan into an invisible moving target.

## Model routing as resource allocation

Each task records:

- best model;
- reasoning effort;
- route class;
- why that model is appropriate;
- actual model used.

The lead stays local when dispatch overhead exceeds likely benefit. A separate bounded worker is used only when an exact model/effort materially helps. Routing failure is fail-open rather than making the mission unusable.

## Context engineering

The harness attempts to keep the model’s active context concentrated on evidence that changes the next decision:

- targeted retrieval before broad scans;
- bounded command/log output;
- structured projection for structured data;
- focused Git diffs;
- no repeated reads of unchanged material without a reason;
- checkpoints that preserve facts/decisions/next action rather than raw transcript noise.

This can reduce waste, but the project does not advertise a universal token-saving percentage because workload shape matters.

## Long-horizon safety

The system checkpoints at task boundaries and monitors Codex quota/session pressure. It does not promise that a model will always receive one final turn before a hard usage cutoff. Instead, it tries to make the current state recoverable **before** that moment by refreshing durable files during normal execution and refusing to start large work too late in a usage window.

## What success means

The project succeeds if Codex becomes more reliable at completing substantial work because the harness improves:

1. task decomposition and dependency clarity;
2. evidence retrieval and context quality;
3. model/reasoning allocation;
4. verification discipline;
5. recovery after interruption;
6. transparency about what was actually done.

That is a practical engineering goal. Whether a model should be called “AGI” is a separate question and is not required for the harness to be useful.
