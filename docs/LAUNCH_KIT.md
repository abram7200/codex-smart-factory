# Launch Kit

## Repository

**Name:** `codex-smart-factory`

**Description:**

> An always-on operating layer for OpenAI Codex: context discipline, project discovery, verification, and live-catalog smart model routing.

**Topics:**

`openai-codex`, `codex`, `agents-md`, `ai-coding`, `agent-skills`, `model-routing`, `context-engineering`, `powershell`, `windows`, `developer-tools`

## v1.0.0 release title

**Codex Smart Factory v1.0.0 — Always-on Core + Smart Model Router**

## Release notes

Codex Smart Factory is a free, open-source operating layer for Codex on Windows.

The essential engineering rules live in one complete always-on global Core rather than depending on a tiny trigger that may or may not load extra references later.

### Highlights

- Full always-on Codex Core: retrieval, debugging, implementation discipline, verification, subagents, safety, long-context handling, and communication.
- Old-project discovery from surviving Codex session/history metadata plus automatic new-project observation.
- Live model-catalog routing with Token Saver / Balanced / Max Quality profiles.
- Benefit-gated exact-model `codex exec` leaf workers; no fake claim that a Markdown file can magically switch the already-running main thread.
- `Check if you are boosted or no?` performs a rollout-backed self-check and reports `PENDING_RESTART` instead of a false positive.
- Existing global instructions are preserved across install/update/uninstall.
- Project `AGENTS.md` files remain repository-owned and are not overwritten.
- Local token/routing reports, backups, repair, tests, and Windows CI.
- MIT licensed. No third-party proxy, credential access, or remote-script installer.

### Install

Download the release ZIP, extract it, run `CODEX_SMART_FACTORY.cmd`, choose **FULL INSTALL / UPDATE**, then restart Codex once.

After restart ask:

```text
Check if you are boosted or no?
```

This is a community project, not an official OpenAI product.

## X / Twitter

I built **Codex Smart Factory** and released it free + open source.

It gives OpenAI Codex an always-on engineering Core for context discipline, debugging, verification, project discovery, and smart model/reasoning routing — without replacing Codex or installing a proxy.

Key design choice: no tiny “loader” prompt that *hopes* the rest gets opened later. The complete Core is loaded globally, while project rules stay project-owned.

Also: ask Codex **“Check if you are boosted or no?”** and it verifies the active session instead of bluffing.

MIT licensed. Feedback and benchmarks welcome.

## LinkedIn

I’ve open-sourced **Codex Smart Factory**, a Windows-first operating layer for OpenAI Codex.

The goal is simple: improve the full path to a correct result — not just make prompts shorter. It adds an always-on engineering Core for targeted retrieval, context management, debugging, validation, subagent discipline, project discovery, and live-catalog model/reasoning routing.

A few design decisions I cared about:

- Essential rules are fully present in the global Codex instruction layer; correctness does not depend on the model deciding to open another reference file later.
- Existing project `AGENTS.md` files remain owned by the project.
- Model routing is honest: it keeps the lead local when routing overhead is not worth it and uses bounded exact-model workers only when the expected benefit is material.
- Installation is reversible and preserves existing global instructions.
- Session JSONL is treated strictly as data, never executed.
- No guaranteed token-saving percentages are claimed without measurement.

The project is MIT licensed and free to use. I’d especially value real-world benchmarks and edge-case reports from Codex users.

## Reddit

**Title:** I open-sourced a Windows operating layer for Codex: always-on rules + project discovery + smart model routing

I’ve been experimenting with ways to make Codex spend less context on noise without sacrificing verification. I ended up building Codex Smart Factory and released it under MIT.

It installs a complete global Core covering retrieval, debugging, validation, subagents, safety, long-session state, and communication. It also keeps a central registry of old/new projects and has a local model router that reads Codex’s model catalog before choosing whether a bounded leaf task is worth sending to another model/effort.

One thing I deliberately did **not** do: claim a Markdown skill can magically switch the already-running main-thread model. The router either stays local, starts an exact `codex exec` leaf, or fails open.

I’d love people to break it, benchmark it, and file issues. In particular I’m interested in first-pass success, retries, cache hit rate, and whether routing overhead actually pays for itself on real repos.

## Hacker News

**Title:** Show HN: Codex Smart Factory – an always-on context and model-routing layer for Codex

Codex Smart Factory is a free Windows-first layer for OpenAI Codex. It installs a comprehensive global `AGENTS.override.md` Core and adds project discovery, session-backed health checks, local token reports, and a deterministic model/reasoning router using Codex’s own model catalog.

The main architectural constraint was to avoid depending on progressive disclosure for essential behavior: the complete operating rules are always loaded globally, while repository instruction files remain untouched. The model router is benefit-gated and uses exact `codex exec` workers for bounded leaves rather than pretending to mutate the current thread model.

MIT licensed; benchmarks and failure reports welcome.

## Launch principles

Do not spam communities or post the same copy everywhere. Lead with the technical design, disclose that it is an independent community project, invite benchmarks, and update claims when evidence changes.
