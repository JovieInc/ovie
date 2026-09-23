# Ovie

The 2026-09-23 founder decision in JOV-6026 makes this private repository the
final home for Ovie. The July Swift menu-bar launcher below remains preserved
as legacy source. `apps/desktop` is a candidate extraction of the maintained
Electron shell from Jovie. It is not a commissioned Ovie app yet.

## Electron extraction status

From a clean clone, Node 22.23.2 and pnpm 9.15.4 install the declared Electron
dependencies. The copied shell typechecks, generates its own Mac icons, and
reaches local package signing. `pnpm desktop:test` is intentionally a required
CI check; five existing cross-surface tests currently fail because the Ovie web
app has not been extracted from `JovieInc/Jovie`. Keep those checks red until
they exercise the real independent web app. The current shell also still loads
`jov.ie`, and its production updater feed still points at Jovie releases.

Do not deploy, install over the existing app, or switch users to this candidate.
Finish the independently built web app and contracts, private origin, auth/MFA,
updater migration, release/rollback and installed runtime proof first. The
existing Jovie compatibility door remains in service through that cutover.

## Legacy Swift launcher

The company OS that runs Jovie's engineering org — a Mac menu-bar app over
the autonomous ship loop (codex-issue-shipper + kanban shipper), built on
the [ship-ledger contract](LEDGER.md) so restarts and auto-updates never
drop in-flight ship jobs.

## What it does today

- Menu-bar status for the shipper: state, dispatchable issues, last run.
- **In-flight jobs from the durable ship ledger** — the journal the
  shipper writes before every dispatch and recovers on startup.
- Ship-owner lock visibility (who owns shipping on this machine, and
  whether that process is alive).
- Pause / resume (`~/.hermes/shipping-paused` sentinel), ledger-safe
  shipper restart, self-relaunch.

## Build & test

```bash
swift build
swift test
swift run   # menu bar app; needs a GUI session
```

## Design

See [DESIGN.md](DESIGN.md) for the MVP plan. The app is adapted from the
proven `JovieInc/Jovie tools/shipping-menu-bar` base. Restart safety comes
from the ledger, not from the app: the shipper's startup recovery releases
any claim whose owner process died, so "restart without losing running
work" is a property of the system, not of careful shutdown ordering.

Auto-update (Sparkle + signed releases + appcast) is the next slice on
this repo — it layers on the same guarantee: an update-triggered relaunch
is just another restart the ledger already survives.
