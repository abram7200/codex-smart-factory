# Per-Agent Adaptive Injection Matrix — Smart Factory × IBN

Status: reviewed design, not deployed. Updated 2026-11-04. One local integration per engineer Windows account; no central AI controller.

## Key distinction

**IBN Brain/OneBrain, Graphify, AI Memory, FastPath, approved Skills, official standards and engineering QA remain one logical authority per PC.** Every installed agent gets a capability-appropriate adapter and only its own instruction/hook format, not a copy of Codex Smart Factory's entire global Core.

Smart Factory's Windows PowerShell Codex worker router is specific to Codex. For Claude, Cursor, OpenCode, Gemini, Antigravity and Copilot, reuse portable mission events, verification contracts and IBN tools only where the agent genuinely supports them. Do not falsely call a non-Codex operation a Codex routed worker.

## Version-checked client matrix

| Client | Candidate surfaces — discover and validate | Recommended integration | Avoid |
|---|---|---|---|
| Codex Windows app/CLI | User/global/project AGENTS and supported Codex config | Native Smart Factory mission/router + IBN read/QA adapter after instruction conflict resolution | Blind global override, noninteractive unrestricted writes |
| Claude Code | CLAUDE.md, supported settings/hooks/skills | Minimal IBN role, native approved context and optional event CLI | Codex-specific model commands |
| Cursor | Verified version-specific rules, supported hooks/skills | Cursor-native instructions and IBN tool bridge, mission receipt where supported | Assuming Claude/Codex schema |
| OpenCode | AGENTS.md and verified OpenCode plugins/config | Native OpenCode role, scoped IBN retrieval and supported events | Unapproved API spend |
| Gemini CLI | GEMINI.md and supported config/hooks | Gemini-specific lightweight IBN role and approved retrieval | Assuming identical to Antigravity |
| Antigravity | Discover actual version, supported configs/hooks | Conditional native adapter after capability probe | Invented hooks or file paths |
| GitHub Copilot | Supported editor/project instructions/extensions | Repository-scoped IBN references and supported tools | Changing project repository policy without approval |
| Other/unknown | No assumed paths | Read-only discovery; manual opt-in before supported adapter | Installing one-size-fits-all role files |

Above are discovery hints, not a guarantee of installed paths or availability. Preserve all native user/project instructions and product policy precedence.

## Adaptive injection algorithm

1. Detect installed agent and version, user scope, supported config, hook, skill and tool interfaces.
2. Inventory current IBN and user-owned instructions; fingerprint and preserve exact bytes outside owned blocks.
3. Build a minimum per-agent profile: IBN-First, official edition/page evidence, scope isolation, no invented values, protected edits, independent verification, truthful reports.
4. Compose into a named, versioned managed block ONLY where supported, with idempotence and fully tested removal.
5. Codex receives full compatible Smart Factory functionality. Other agents receive only supported IBN and portable mission/event features, not an unsupported Codex router.
6. Validate in a FRESH real agent session: read-only IBN lookup with cited evidence, protected-write denial, profile priorities, correct tool invocation. Mere files present is NOT success.
7. On agent upgrades, re-detect compatible versions rather than silently injecting old formats.
8. Uninstall only owned changes; preserve user edits and original data.

## Capability negotiation example

    {
      "schema_version":"1.0",
      "agent_id":"codex",
      "client_version":"OBSERVED_OR_UNKNOWN",
      "instructions_supported":true,
      "hooks_supported":null,
      "skills_supported":null,
      "ibn_brain_connected":false,
      "ibn_memory_connected":false,
      "ibn_graphify_connected":false,
      "mission_events_supported":null,
      "validation":"NOT_TESTED"
    }

All capabilities must be observed; null means unknown, not false proof.

## Extra acceptance gates A01-A10

- A01: enumerate exactly installed agent clients, with versions and evidence.
- A02: inject correct agent-specific instructions; never distribute identical Codex Core to all.
- A03: demonstrate IBN-First and native instructions work in fresh actual sessions.
- A04: preserve unrelated user-owned instructions on install/update/uninstall.
- A05: unsupported hooks degrade to a safe manually invoked/read-only mode.
- A06: verify a real project/client-scoped IBN Brain lookup from each supported agent.
- A07: verify protection of official engineering data and Skill Recorder approval.
- A08: prevent credential propagation, hidden external calls and unexpected paid billing.
- A09: prove idempotent repair, update and rollback for every installed adapter.
- A10: report absent or unsupported agents honestly as NOT_AVAILABLE or NOT_TESTED.

## Engineer intent and reporting

All agents must apply a common engineer request contract: explicit user instructions versus source-verified requirements versus proposals versus unknowns. No engineering claim without source/edition/page or native model evidence. Finish with a factual task report: requested work, actions, output files, checks run, issues, unknowns, actual model and token usage if observed, and next action.

**Go/no-go:** This is a design for an agent-specific native adapter system, not evidence that all listed agents currently support automation or that multi-agent integration has passed tests.
