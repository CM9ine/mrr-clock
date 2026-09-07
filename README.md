# MRRClock

A macOS menu bar app that answers one question, all day, every day:

> **Am I on track?**

You add goals — a name, a target date, and optionally a target amount. It shows the
countdown, live MRR from Stripe, total earned to date, and a projection of where the
current rate lands you by that date. Pin one goal to the menu bar.

Goals are data, not settings — stored in `goals.json`, editable in the app. Nothing about
a goal is compiled in.

```
┌──────────────────────────────────────┐
│  Buy a house                     ▾   │
│  29 Sep 2027 · 387 days              │
│                                      │
│  MRR              $1,240 /mo         │
│  Earned to date  $18,430             │
│  Projected       $34,200  by 29 Sep  │
│                                      │
│  Aurora  $820  Beacon $310  Other $110│
│                                      │
│  Synced 2m ago      ↻      ⚙︎        │
└──────────────────────────────────────┘
```

Menu bar title (configurable): `387d · $1.2k`

## Status

**Planning — no code yet.** The plan is complete and broken into 19 tasks, tracked as
[issues #1–#19](https://github.com/CM9ine/mrr-clock/issues) across
[six milestones](https://github.com/CM9ine/mrr-clock/milestones). Start at
[#1](https://github.com/CM9ine/mrr-clock/issues/1) and work in order.

## Read in this order

| Doc | What it is |
| --- | --- |
| [docs/PLAN.md](docs/PLAN.md) | The goal, the funding math, scope, milestones |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Modules, data flow, file layout |
| [docs/METRICS.md](docs/METRICS.md) | Exact definitions of goals, MRR, earned and projected — the spec tests are written against |
| [docs/STRIPE.md](docs/STRIPE.md) | Restricted key setup, endpoints, pagination, errors |
| [docs/TDD.md](docs/TDD.md) | The working rules for every task |
| [docs/TASKS.md](docs/TASKS.md) | The ordered task list |
| [docs/tasks/](docs/tasks/) | One file per task, each with its tests spelled out |
| [docs/AGENT-PROMPT.md](docs/AGENT-PROMPT.md) | The reusable prompt for an agent implementing the next task |

## Stack

- Swift 6.3 / SwiftUI `MenuBarExtra`, macOS 14+
- Swift Package Manager for the testable core, thin Xcode shell for the app
- [Swift Testing](https://developer.apple.com/documentation/testing) (`import Testing`) for tests
- No server, no database, no dependencies. Stripe restricted key lives in the macOS Keychain.
