# Ship Ledger Contract

The cross-process contract between the shipper (`JovieInc/Jovie
scripts/hermes/lib/ship-ledger.ts` — the source of truth) and this app.
Both sides can restart at any moment without dropping in-flight ship work.

## Files (machine-global — never derived from `HERMES_HOME`)

Profile-scoped `HERMES_HOME` overrides are how two "singleton" shippers
raced one GitHub queue (JovieInc/Jovie#12723). These paths are fixed:

| File | Writer | Purpose |
|---|---|---|
| `~/.hermes/state/ship-owner.lock` | shipper | One shipper owner per machine. JSON: `{"caller": string, "pid": number, "ts": epoch-ms}`. Held for the duration of a run; broken by the next claimant when the owner pid is dead or the lease is older than `SINGLETON_LOCK_STALE_MS`. |
| `~/.hermes/state/inflight-ship-jobs.json` | shipper | JSON array of in-flight dispatches. Entry: `{"job", "repo", "issue", "branch", "worktree", "pid", "startedAt"}`. Written before the coding agent starts, removed at every terminal path. Atomic tmp+rename writes. |

## Recovery ownership

**The shipper owns recovery.** On every start (under the owner lock) it
reads the journal and, for each entry whose `pid` is dead: releases the
GitHub claim label, comments, prunes the worktree, drops the entry, and
logs `restart_recovered_claim`. Work is requeued, never stranded.

Ovie therefore treats restarts — its own, the shipper's, or an
auto-update of either — as always safe. Ovie only **reads** these files;
a reader crash can't corrupt them, and corrupt/missing files read as
empty on both sides.

## Compatibility rules

- New fields may be added to journal entries; readers must ignore
  unknown fields (both current readers do).
- Never change the meaning of `pid` — liveness of that pid is the entire
  recovery predicate.
- Keep writes atomic (tmp + rename) so a crash mid-write reads as the
  previous state, not corruption.
