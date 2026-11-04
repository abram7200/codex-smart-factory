# IBN × Codex Smart Factory — Code-Grounded Integration Evaluation

**Review:** 2026-11-04 | **Smart Factory base:** main @ c74d25baf17020aad9bdabe3fad063f1faf2cea0 | **Reference release:** v1.1.4

> Status: CONDITIONAL / NOT INTEGRATION-VERIFIED. This document is for per-engineer local Windows integration, not a central controller. No internal IBN Drive IDs, confidential source, project files, private company paths, or credentials are included.

## Executive assessment

Smart Factory has functional mission DAGs, recovery/checkpoints, Codex model routing, a session watcher, token accounting and Windows CI tests. IBN already has domain-specific OneBrain/Brain, Graphify, AI Memory, FastPath, Skill Fusion, Skill Recorder, standards libraries and CAD/BIM execution gates. The integration should be **an adapter with explicit ownership and tests**, never a duplicate brain/graph/memory.

Public code was inspected directly. Private IBN implementation was assessed from authorized source and release evidence; a complete historical deployment archive or a live engineer workstation was not executed here. Therefore installed version, skill count, graph integrity and safety must be independently verified on each PC.

## Confirmed release blockers

**SF-01 — global instruction collision (CRITICAL).** `src/runtime/Install-Global.ps1` composes the roughly 29.5 KB `src/CORE_AGENTS.md` into `%CODEX_HOME%\AGENTS.override.md`. Preserving original text is not equivalent to preserving effective IBN-First behavior. Implement named-block ownership, semantic conflict detection, actual Codex precedence checks, context budget control, idempotency, user-edit preservation and reversible uninstall. Verify real new-session injection.

**SF-02 — uncontrolled write execution (CRITICAL).** `src/router/Smart-Exec.ps1` passes `approval_policy="never"`, chooses `workspace-write` for keyword-detected edit tasks and includes `--skip-git-repo-check`. Implement enforced read-only-by-default execution, path validation and reparse/symlink checks, explicit approval for protected drawings, codebooks, standards, Skills and IBN stores, audit trail and adversarial negative tests. Do not rely on instruction text as permission enforcement.

**SF-03 — English-centric router (HIGH).** `src/router/Router.ps1::Get-TaskFeatures` primarily scores English keywords, so Arabic HVAC/MEP/CHW requests can be under-classified. Replace English-only risk signals with a deterministic, testable bilingual engineering feature model, with IBN discipline, source, Skill and verification-burden signals. Preserve explicit user-selected models; read the available local Codex catalog; no new paid API dependency.

**SF-04 — release integrity (HIGH).** `distribution/ASTRA_AGI_HARNESS.cmd` downloads the GitHub tag archive and checks version/files/precheck, but does not visibly verify a SHA-256 digest for that *exact* downloaded archive before running its scripts. The published release ZIP checksum is not interchangeable with an auto-generated tag ZIP checksum. Use pinned artifact identity, matching digest with a trusted signing/pinning method, staging, safe extraction, atomic activation and tested rollback.

## Other observed issues to evaluate

- `src/runtime/Status.ps1` accepts heartbeats younger than 180 seconds whereas installer health uses under 20 seconds. Align liveness criteria and test stale PID/hung watcher.
- `src/runtime/Watcher.ps1` reads Codex JSONL CWD metadata: this is project discovery, not a live multi-agent monitor or proof that a current task is executing.
- `src/runtime/Token-Report.ps1` reports observed Codex token events; it cannot prove token savings or all-agent usage.
- Mission state is persisted in each project's `.codex-smart-factory` directory: prevent unapproved project pollution, shared-drive writes and concurrent state corruption.
- Checkpointing under quota pressure is not a bypass of server-side limits, and must not trigger unauthorised paid credits.
- Historical mission documentation still includes older STOP wording; reconcile emitted instructions with v1.1.4 checkpoint behavior.
- Existing IBN Skill Recorder promotion, native engineering validation, client/project/office scopes and standards edition/page citations are binding constraints.
- IBN's thousands of source/agent/custom Skills, support files, variants and owner manifests demand an ownership-aware inventory; filename-only dedupe is destructive.
- AutoCAD/Revit live models are protected native execution surfaces, not generic Git code workspaces.
- Memory and Graphify updates require native APIs, provenance, approval and idempotency; historical inferred graph edges are not approved engineering facts.

## Correct ownership and architecture

1. Codex runs locally per engineer. Existing IBN-First instructions remain effective.
2. IBN Brain / OneBrain owns engineering reasoning, source citations, skill choice, native execution, QA and verified knowledge.
3. Smart Factory owns Codex mission task DAG, model suggestions, checkpoints and worker lifecycle.
4. A versioned adapter maps mission/task IDs to IBN execution IDs, read-only context requests and approved writeback events.
5. Graphify and AI Memory remain the existing stores. No parallel graph database or AI memory system.
6. Engineering success requires the native independent verification result, not just `codex exec` exit code or `complete-task -Verified`.

## Agent contracts

**Capability negotiation:** return installed IBN/CSF/Codex versions, path/ownership evidence, available native interfaces, read/write permissions and schema version.

**Context retrieval:** accept project/client/office scope, discipline, question, token budget, source/edition policy; return bounded evidence references and Skill hashes with VERIFIED/EXTRACTED/INFERRED/UNKNOWN labels.

**Mission mapping:** stable `csf_mission_id`, `csf_task_id`, `ibn_execution_id`, `run_id`, idempotency key and UTC timestamps. Separate coding-worker done from engineering approval.

**Verified persistence:** only write source-backed facts to the existing approved AI Memory and Graphify APIs after engineering review. Preserve stable graph IDs, scope and provenance; replay identical events safely.

**Local truthful status:** ACTIVE/IDLE/PAUSED/BLOCKED/COMPLETED/FAILED/UNKNOWN/UNAVAILABLE with evidence timestamp; never infer live activity just from historical CWD.

## Large-scale IBN inventory requirements

Enumerate all installed canonical toolkit, Revit-extension, agent-specific and custom skill roots; record each Skill's owner marker, relative ID, SKILL.md digest, full support-file tree hash, provenance, variants, tool requirements and native executor links. Keep foreign/custom Skills intact. Inventory graph node/edge types, orphan and provenance counts, memory hooks, standards/editions, codebooks, native tools, live CAD version compatibility, and update ownership. Use incremental indexes; never load the whole graph or all skills into model context. Counts from old logs are historical and must be remeasured on this workstation.

## Mandatory validation gates (G01–G30)

| Gate | Outcome required |
|---|---|
| G01–G04 | Authoritative installed IBN release, scoped Skill inventory, provenance and support files verified |
| G05–G06 | Codex global instructions compatible; reinstall/uninstall preserve user and IBN edits |
| G07–G08 | Read-only default and protected writes technically enforced with approval |
| G09–G10 | Arabic/English engineering routing parity; catalog-grounded model selection |
| G11–G12 | Exact artifact integrity verified; no central service or unapproved elevation |
| G13–G17 | Scoped Brain, Graphify, Memory and Skill Recorder read/write/approval tests |
| G18–G19 | Stable mission IDs; IBN independent QA gates final engineering completion |
| G20–G21 | Honest worker telemetry and checkpoint/quota behavior |
| G22–G24 | Concurrency, native CAD file protection and official source/edition integrity |
| G25–G27 | Crash/partial-write recovery, repeatable update and rollback tests |
| G28–G30 | Watcher liveness, fresh Windows-user portability, evidence-rich acceptance pack |

Each gate requires command, observed output, environment, status PASS/FAIL/BLOCKED/NOT_TESTED and evidence location. An untouched gate is NOT_TESTED, not PASS.

## Implementation sequence

1. Isolated local staging and baseline inventory. Preserve all currently installed IBN sources, Skills and user's instruction files.
2. Reproduce and fix SF-01..SF-04; add safety regression tests and patch stale watcher/quota text.
3. Read-only IBN capability/Brain/Graphify/Skills adapter and permission-scoped retrieval.
4. Mission ID mapping, durable event ledger, checkpoint and status reconciliation.
5. Verified-only native Memory/Graphify writeback and Skill Recorder gate integration.
6. Bilingual engineering routing and protected native execution policy.
7. Pinned per-user installer, repair/uninstall and rollback.
8. Genuine Windows 10/11-compatible host tests, isolated synthetic CAD/BIM fixtures and G01–G30 acceptance; no live drawing changes for testing.

## Source pointers

- `src/runtime/Install-Global.ps1`, `Common.ps1`, `Watcher.ps1`, `Status.ps1`
- `src/router/Router.ps1`, `Smart-Exec.ps1`
- `src/mission/Mission.ps1`, `MissionCommon.ps1`, `QuotaCommon.ps1`
- `distribution/ASTRA_AGI_HARNESS.cmd`, `INSTALL.ps1`, `tests/`, `.github/workflows/ci.yml`

**Go/no-go:** Existing Smart Factory v1.1.4 may be valuable for local Codex task orchestration; unconditional deployment over live IBN engineering workspaces is NO-GO until these fixes and tested adapter are complete. This document is a specification, not a certification.