# Ovie

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
