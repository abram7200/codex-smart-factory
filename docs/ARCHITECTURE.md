# Architecture

## 1. Always-on Core

The Core is installed in `$CODEX_HOME/AGENTS.override.md`. This is the only place that contains the complete operating rules. The runtime does not depend on progressive disclosure for essential behavior.

Pre-existing global instructions are preserved in the composed override.

## 2. Repository rules remain repository-owned

Smart Factory does not duplicate the Core into project AGENTS files. Codex itself applies global + project instruction layers. Keeping the Core global prevents project instruction-budget duplication and repository pollution.

## 3. Central project registry

Project discovery parses Codex rollouts as untrusted data, extracts CWD values, resolves project roots, and stores profiles under `$CODEX_HOME/smart-factory/state/`.

No project source file has to be modified.

## 4. Model router

The router is local/deterministic:
- inspect live Codex catalog;
- score task risk/complexity;
- select role/model/effort;
- apply benefit gate;
- stay local or use exact `codex exec`.

It does not use a separate classifier model, so routing itself does not consume another inference call.

## 5. Self-check

Status checks installation plus actual session rollout evidence. This distinguishes:
- installed;
- injected in current session;
- stale current session needing restart.
