# Ovie MVP Design — Smallest Viable Slice (Fable-Class)

**Purpose**: Ship auto-updating Mac app skeleton first so ops (gbrain/shipper) inherit immediately. Enable constant self-update, issue pull, autonomous PR shipping via existing models (Codex/Claude/CodeX CLI patterns from Jovie). Include settings UI + better auth. New JovieInc repo. Full tests + auto-reload. Delegate research/design to cheap subagents before any build.

**Effort**: high (architectural, long-horizon autonomy, multi-agent convergence)

**Boundaries**:
- No full feature bloat. Smallest that runs here, self-updates, pulls 1-2 issues, ships 1 PR autonomously.
- Auto-update first (Sparkle or equivalent).
- Reuse Jovie patterns: shipping-menu-bar Swift base, hermes/shipper logic, gbrain context.
- No new model training; use existing (local GGUF? or CLI delegation).
- Converge gbrain/shipper/ops immediately.

## Fable 5 Prompting Map for Path

**Core Prompt Template (for all delegations/research)**:
```
Task effort: high
I'm building Ovie (autonomous ops Mac app) for JovieInc to converge gbrain/shipper/ops. Stakeholders need constant self-updating skeleton that pulls issues + ships PRs via existing models, with settings + improved auth. This enables ops to inherit auto-update immediately then iterate with tests/auto-reload.

[Specific subtask: e.g. research Mac auto-update frameworks for SwiftUI menu bar app]

When you have enough information to act, act. Do not re-derive facts already established.
Lead with outcome. Ground every claim in tool results or session evidence.
```

**Delegation Plan (use mcp_hyperagent or claude-code/codex skills)**:

1. **Research Subagent (Eve or Developer agent)**: 
   - Query: Mac auto-updating app skeleton (Sparkle vs Squirrel vs built-in, SwiftUI + menu bar + settings). Minimal viable for self-update constant polling. Include code examples that compile/run on macOS 13+.
   - Output: 1-page spec + 3 file skeleton (App.swift, SettingsView.swift, UpdateManager.swift). Ground in existing shipping-menu-bar.

2. **Auth Research Subagent**:
   - Better auth: GitHub OAuth + Linear + model provider keys (store in Keychain, like Jovie Clerk proxy patterns). Settings UI for token input/refresh.
   - Delegate to "Tim White Writer" or Developer for voice-consistent spec.

3. **Integration Research (gbrain/shipper convergence)**:
   - How to embed shipper logic (codex-issue-shipper.ts patterns) into Mac app for autonomous dispatch. Issue pull via GitHub/Linear APIs. PR ship via CLI delegation (hermes jobs or codex CLI).
   - Poll ~/.hermes/logs, launchctl for shipper state.

4. **Build Delegation**:
   - After research complete (checkpoint), delegate coding to "Developer" hyperagent or codex/claude-code skill.
   - First deliverable: auto-update only (ship this slice).
   - Then: settings + auth.
   - Then: issue pull + PR ship buttons (autonomous loop).

**MVP Scope (Smallest Viable)**:
- SwiftUI Mac app (menu bar or small window) based on shipping-menu-bar.
- Auto-update: Integrate Sparkle framework; constant check on launch + timer.
- Settings UI: SwiftUI sheet or prefs window for API keys, model choice, pause/resume, repo config.
- Better auth: Keychain storage, OAuth flow for GitHub (ASWebAuthenticationSession), refresh tokens.
- Core loop: Button "Pull Issues" (uses gh/Linear API via existing Jovie lib patterns), "Ship PRs" (delegates to codex-issue-shipper or model CLI, autonomous).
- Self-update constant: Background timer + update check.
- Tests: XCTest for update manager, auth flows. Auto-reload via Swift hot-reload or rebuild script.
- Run here: `swift build && swift run` or release binary with Sparkle.
- Repo: JovieInc/ovie (this dir). Mirror Jovie AGENTS.md, CLAUDE.md patterns.

**Path Forward (Fable-Grounded)**:
- Delegate research NOW (parallel subagents via hyperagent threads).
- Audit existing: shipping-menu-bar, Jovie shipper scripts, gbrain LaunchAgents.
- Once research grounded, build auto-update skeleton ONLY.
- Verify run + self-update on this Mac.
- Iterate: add settings/auth, then autonomous features.
- Store lessons in JovieInc/LESSONS.md (one per file, 1-line summary).
- No unrequested features. Verify-before-done on every slice.

**Next Immediate Action**: Delegate research threads for auto-update + auth. Report back only when evidence gathered.

This maps the full path: research → design → auto-update ship → iterate with delegation. Ops inherits update mechanism immediately.