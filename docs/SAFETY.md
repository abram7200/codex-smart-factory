# Safety model

- Rollout/session JSONL is data only; never source/eval/execute it.
- Credentials/auth/config are not copied.
- `config.toml` is not rewritten.
- Global instruction edits are backed up. Smart Factory never rolls back `AGENTS.md`; it records whether an override pre-existed and removes/restores only its own global override layer while preserving user edits.
- Project AGENTS files are not rewritten.
- Routed workers are read-only or workspace-write only.
- No automatic `danger-full-access`.
- No remote shell bootstrap.
- No third-party proxy/plugin is silently installed.
- Uninstall restores preserved global instructions.
