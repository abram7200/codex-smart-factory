# Engineering Intent, Verified Evidence, Token Economy and Task Reporting

Status: design and acceptance specification (not an implemented feature). 2026-11-04. Applicable to every agent with a validated IBN adapter, not just Codex.

## Problem statement

A generic coding agent often misinterprets engineer requests, expands scope, guesses technical data or standards, selects incorrect Skills, repeats failed attempts, burns tokens re-reading unchanged files, then reports code execution as if engineering approval occurred. Smart Factory's mission DAG and verification fields alone cannot prevent these failures. IBN contains the domain knowledge and tools needed to supply stronger evidence and native engineering validation.

## F01 — Engineer Intent Compiler

Create a typed immutable Engineer Request Contract before routing:

- Literal user requirements with source offsets, nouns (discipline, floor, system, space, project), numerical quantities and units.
- Explicit exclusions, expected file formats, named project inputs, scope and revision.
- Attached-source evidence and the required deliverable/acceptance rule for each action.
- Distinguish USER_EXPLICIT, SOURCE_VERIFIED, ENGINEER_APPROVED, PROPOSED, UNKNOWN, and CONFLICT.
- Separate user intent from defaults. Prior conversation/examples are context, not permission to override this request.
- Preserve original Arabic and English phrases and technical abbreviations; normalize synonyms without losing meaning.
- Generate a compact engineer-readable receipt: what was asked, what will be produced, what will not be changed, missing essential inputs and verifications.

Readiness states: READY; READY_WITH_DISCLOSED_ASSUMPTIONS; NEEDS_ESSENTIAL_INPUT; BLOCKED_BY_SOURCE; CONFLICTING_REQUIREMENTS.

Do not invent a load, pressure setpoint, ACH, NFPA spacing, drawing coordinate, revision, source citation or CAD ElementId. If a missing fact is essential, use safe discovery then ask precisely for the necessary fact. For nonessential uncertainty, maintain an unresolved item and avoid claiming final approval.

## F02 — Evidence Resolver / No-Fabrication Gate

Resolve claims using existing IBN standards library, Brain/OneBrain, Graphify and source-backed Skills. Record claim ID, exact source document, edition/revision, clause/page or native model reference, file hash, scoped project/client, extraction method, observed confidence, provenance tier and verifier.

Official governing code/project source takes priority over inferred graphs, prior project patterns and model recollection. An IBN Skill is guidance unless its required executor and test evidence are present. Reject unsupported clause/page references, mismatched standard editions and cross-project leakage. Use SOURCE_NOT_FOUND and SOURCE_CONFLICT states. No unverified facts become durable memory or approved graph edges.

## F03 — Scale-Aware Skill Resolver

IBN historical v16 installer reported 7,517 canonical Skills, installed in several agent roots alongside user-owned variants. Do not load the full catalog into context or dedupe by display name. Index by content hash, owner manifest, relative path, supporting file tree, approved scope, discipline, executor/runtime compatibility, last verification and provenance. Retrieve a small ranked candidate set through existing IBN FastPath/Brain; return a Skill Selection Receipt with why, hash, what executable was actually used and missing prerequisites. Cache on digest and re-index changed items.

## F04 — Scoped Self-Organizing Missions

Build dependency DAG from engineer acceptance tests, not speculative task inflation. Keep a single accountable mission owner, stable task IDs, bounded parallelism only for non-overlapping writes, and dynamic discovered work classification. New issues are registered with evidence and relation (blocker/required/related/follow-up/out-of-scope); do not silently expand scope. Require a change in hypothesis or inputs before identical retry; after a bounded repeat threshold, diagnose or escalate instead of consuming a loop of tokens.

Track implementation states independently: PLANNED, IN_PROGRESS, IMPLEMENTED, TECHNICALLY_CHECKED, ENGINEERING_VERIFIED, ENGINEER_APPROVED. A worker saying 'verified' does not imply compliance or engineer approval.

## F05 — Token and Context Budget Controller

Budget by phase: interpret, retrieve, plan, execute, verify, report. Reserve context for verification and final reporting. Use IBN FastPath/Graphify ranked retrieval, content hashes, incremental diffs, bounded logs, selective source ranges and checkpoint summaries. Detect repeated low-yield searches and identical failures. Do not spend tokens to classify trivial work if local deterministic rules suffice. Escalate effort for risk and verification burden, not merely prompt length.

Important: no hard universal token-saving percentage; compare actual tasks with baseline and regression quality. Never reduce retrieval or verification below the engineering correctness gate. Observe actual telemetry only; do not equate estimated cost to billed money.

## F06 — Independent Engineering Verification

Require applicable native engine checks (AutoCAD/Revit, Python calculation, geometry, layers, standards, source revision, units and tolerances), controlled visual inspection and source backed discrepancy reports. Native read-only safeguards must be used for unapproved projects. Identify exact project/drawing, version, execution scope, before/after change and proof. Technical tests versus engineering tests versus professional signoff are separate.

## F07 — Learning Without Corrupting IBN

After verified work, build a small deduplicated learning candidate for existing IBN Skill Recorder and AI Memory. Never bypass human review, HMAC/evidence gates or trusted edition requirements. Maintain project/client/office scope isolation. Write Graphify only via supported API with stable IDs, provenance and replay protection. Retain rejected attempts as bounded, reversible lessons where allowed, not as official rules.

## F08 — Post-Task Engineer Report Generator

Every supported agent must generate the SAME compact report format with agent-specific evidence:

1. Request receipt and constraints actually honored.
2. Actions executed, file paths, hashes/diffs and affected drawing/model IDs.
3. Real verification performed and exact results; what was NOT tested.
4. Engineering claims and their source edition/page or native evidence IDs.
5. Open blockers, assumptions and not-found information.
6. Task / mission statuses and actual model(s) used.
7. Observed tokens, retries and elapsed runtime if available; otherwise UNKNOWN.
8. IBN Memory/Graphify writes: approved / proposed / skipped, with receipt IDs.
9. Explicit next action or handover checkpoint.
10. Overall classification: PASS, PARTIAL, BLOCKED or FAILED; never label a partial deliverable 'complete'.

Example report fields: request_id, agent_id, run_id, project_scope_id, intent_status, source_receipts, task_results, files_changed, qa_tests, unknowns, blockers, verification_state, human_approval, model_usage, token_usage_observed, learning_receipts, checkpoint, final_status.

## F09 — Mistake Prevention / Adversarial Evaluation

Test Arabic/English paraphrase parity, negation and explicit exclusion, unit conversions, conflicting standards editions, incomplete HVAC loads, nonexistent room numbers, unknown Revit ElementIds, missing CAD drawing, user-provided invalid reference, duplicate/custom Skill names, cross-client scope isolation, graph edges marked INFERRED, and repeated failing tool calls. Grade requirement coverage and factual provenance; reject fabricated citations. Include direct comparison to baseline Codex/Smart Factory before claiming improvement.

## F10 — Self-Optimization Under Governance

Observe verified outcomes across tasks and recommend routing or retrieval policy improvements based on evidence. Do not automatically rewrite official engineering standards, Skill Recorder approval policy or global instruction core. Any model-selector threshold change requires offline replay and no-regression checks. Intelligent self-organization means adapting the work plan and recovery strategy within authorization, not autonomous expansion of scope or unsupervised model billing.

## Proposed objective function

Minimize expected verified-completion effort = inference cost + retrieval cost + repeated work + defect/review cost + repair cost, **subject to hard requirements** for evidence, authorized writes, IBN official standards, skill ownership, privacy and human approval. Token reduction is subordinate to engineering correctness and documented evidence.

## Tests E01–E12

- E01: 100% explicit requirements mapped to acceptance conditions or justified OPEN items.
- E02: Arabic/English equivalent requests yield consistent interpretation and risk.
- E03: Negated requirements remain excluded.
- E04: Unprovided critical engineering parameters remain UNKNOWN.
- E05: No invented standards pages/clauses or edition substitution.
- E06: Skill selection returns owner, hash, dependencies and executor proof.
- E07: Failed identical tool attempts trigger diagnostic change, not unlimited retries.
- E08: Task final state cannot bypass native independent QA.
- E09: Graphify/AI Memory writeback requires verified, authorized receipts.
- E10: Token use is actually observed or marked UNKNOWN; reserved reporting budget enforced where telemetry permits.
- E11: Final task report contains evidence, gaps, affected files and handover state.
- E12: Benchmarks include quality/regression alongside latency and tokens; no fabricated efficiency gains.

## Implementation priority

Implement F01+F02+F08 first, because wrong requirements and unsupported facts can invalidate all further optimization. Next F03+F04+F06, then F05+F07+F09+F10. Validate independently in each installed agent using [AGENT_ADAPTER_MATRIX.md](AGENT_ADAPTER_MATRIX.md).

**Acceptance:** an engineer can compare the final report with the original instruction and independently determine what was done, where evidence came from, what remains unknown, and whether engineering approval actually happened.
