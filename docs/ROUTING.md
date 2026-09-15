# Model routing policy

Routing minimizes total task-completion cost, not single-call price.

## Inputs
- ambiguity;
- coupling;
- reversibility;
- validation burden;
- previous failure;
- security/production/data consequence;
- task size (weak signal only).

## Profiles
Token-saver raises escalation thresholds.
Balanced is the default.
Max-quality lowers escalation thresholds but still retains the worker benefit gate.

## Worker rule
A different model is useful only when the work can be bounded well enough that duplicated context and integration do not erase the benefit.

## Live catalog
The router first uses the local `models_cache.json` when available, then refreshes via `codex debug models`, with bundled models as a final fallback. Hidden/internal entries are filtered. Supported reasoning levels are read from the selected model and Ultra is excluded from automatic selection.

## Manual control
Explicit user model/effort choice wins.
